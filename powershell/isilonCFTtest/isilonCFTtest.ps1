### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$isilon,   # the isilon to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username 
    [Parameter()][string]$password = $null,  # optional, will be prompted if omitted
    [Parameter()][string]$path = $null,      # optional if listing or deleting snapshots
    [Parameter()][switch]$listSnapshots,     # list available snapshots and exit
    [Parameter()][string]$firstSnapshot = 'cohesityCftTestSnap1',   # specify name or id of first snapshot
    [Parameter()][string]$secondSnapshot = 'cohesityCftTestSnap2',  # specify name or id of second snapshot
    [Parameter()][switch]$deleteSnapshots,    # delete the specified snapshots and exit
    [Parameter()][string]$deleteThisSnapshot = $null,  # delete one snapshot and exit
    [Parameter()][int64]$port = 8080
)

. $(Join-Path -Path $PSScriptRoot -ChildPath isilon-api.ps1)

if($isilon -notmatch ':'){
    $isilon = "{0}:{1}" -f $isilon, $port
}

isilonAuth -endpoint $isilon -username $username -port $port -password $password

# check licenses
$licenses = isilonAPI get /platform/1/license/licenses
$license = $licenses.licenses | Where-Object name -eq 'SnapshotIQ'
if(!$license){
    Write-Host "This Isilon is not licensed for SnapshotIQ" -foregroundcolor Yellow
    exit
}

# check changelistcreate job is enabled and get policy and priority settings
$jobTypes = isilonAPI get /platform/1/job/types
$jobType = $jobTypes.types | Where-Object id -eq 'ChangelistCreate'
if(!$jobType -or $jobType.enabled -ne $True){
    Write-Host "Change File Tracking is not enabled on this Isilon" -foregroundcolor Yellow
    exit
}else{
    $priority = $jobType.priority
    $policy = $jobType.policy
}

# get list of snapshots
$snapshots = isilonAPI get /platform/1/snapshot/snapshots
if($path){
    $snapshots.snapshots = $snapshots.snapshots | Where-Object path -eq $path
}

# list snapshots and exit
if($listSnapshots){
    $snapshots.snapshots | Format-Table -Property id, path, name, @{l='created'; e={usecsToDate ($_.created * 1000000)}}, @{l='age (hours)'; e={[math]::Round(((Get-Date) - (usecsToDate ($_.created * 1000000))).TotalHours)}}
    exit
}

$initialSnap = $snapshots.snapshots | Where-Object {$_.name -eq $firstSnapshot -or $_.id -eq $firstSnapshot}
$finalSnap = $snapshots.snapshots | Where-Object {$_.name -eq $secondSnapshot -or $_.id -eq $secondSnapshot}

# delete one snapshot
if($deleteThisSnapshot){
    $thisSnap = $snapshots.snapshots | Where-Object {$_.name -eq $deleteThisSnapshot -or $_.id -eq $deleteThisSnapshot}
    if($thisSnap){
        Write-Host "Deleting snapshot $($thisSnap.id)"
        $result = isilonAPI delete "/platform/1/snapshot/snapshots/$($thisSnap.id)"
    }else{
        Write-Host "No matching snapshot found" -foregroundcolor Yellow
    }
    exit
}

# clean up
if($deleteSnapshots){
    # delete old snapshots
    Write-Host "Cleaing up old snapshots..."
    Remove-Item -Path ./cftStore.json -Force -ErrorAction SilentlyContinue    
    if($initialSnap){
        $result = isilonAPI delete "/platform/1/snapshot/snapshots/$($initialSnap.id)"
    }
    if($finalSnap){
        $result = isilonAPI delete "/platform/1/snapshot/snapshots/$($finalSnap.id)"
    }
    exit
}

# avoid using an older second snapshot
if($initialSnap -and $finalSnap){
    if($finalSnap.created -le $initialSnap.created){
        if($finalSnap.name -eq "cohesityCftTestSnap2"){
            $result = isilonAPI delete "/platform/1/snapshot/snapshots/$($finalSnap.id)"
            $finalSnap = $null
        }else{
            Write-Host "Invalid: second snapshot ($secondSnapshot) is older than the first snapshot ($firstSnapshot)" -foregroundcolor Yellow
            exit
        }
    }
}

# phase 1
if(!$initialSnap){
    if(!$path){
        Write-Host "Path is required" -foregroundcolor Yellow
        exit
    }
    Write-Host "Creating initial snapshot, please wait for file changes, then re-run the script to calculate CFT performance"
    $initialSnap = isilonAPI post /platform/1/snapshot/snapshots @{"name"= $firstSnapshot; "path"= $path}
    if($initialSnap){
        Write-Host "New Snap ID: $($initialSnap.id)"
    }
    Remove-Item -Path ./cftStore.json -Force -ErrorAction SilentlyContinue
    exit
}

# create second snapshot
if(!$finalSnap){
    $path = $initialSnap.path
    Write-Host "Creating second snapshot"
    $finalSnap = isilonAPI post /platform/1/snapshot/snapshots @{"name"= $secondSnapshot; "path"= $path}
    if($finalSnap){
        Write-Host "New Snap ID: $($finalSnap.id)"
    }
    Remove-Item -Path ./cftStore.json -Force -ErrorAction SilentlyContinue
    if(!$finalSnap){
        exit
    }
}


# create CFT job
if(! (Test-Path -Path 'cftStore.json')){
    $nowMsecs = [int64]((dateToUsecs) / 1000)
    $newCFTjob = @{
        "allow_dup" = $false;
        "policy" = $policy;
        "priority" = $priority;
        "type" = "ChangelistCreate";
        "changelistcreate_params" = @{
            "older_snapid" = $initialSnap.id;
            "newer_snapid" = $finalSnap.id
        }
    }
    Write-Host "Creating CFT Test Job"
    $job = isilonAPI post  "/platform/1/job/jobs?_dc=$nowMsecs" $newCFTjob
    $jobId = $job.id
    $startTimeUsecs = dateToUsecs
    @{'jobId' = $jobId; 'startTimeUsecs' = $startTimeUsecs} | ConvertTo-Json | Out-File -FilePath cftStore.json
    # exit
}

# calculate hour different between the two snapshots
$initialSnapCreateTime = usecsToDate ($initialSnap.created * 1000000)
$finalSnapCreateTime = usecsToDate ($finalSnap.created * 1000000)
$hoursApart = ($finalSnapCreateTime - $initialSnapCreateTime).TotalHours

# get CFT job status
$cftStore = Get-Content cftStore.json | ConvertFrom-Json
$jobId = $cftStore.jobId
$startTimeUsecs = $cftStore.startTimeUsecs

$reportedWaiting = $false

while($True){
    $reports = isilonAPI get /platform/1/job/reports?job_type=ChangelistCreate    
    $reports = $reports.reports | Where-Object job_id -eq $jobId
    if($reports.count -ge 4){
        $endTimeUsecs = $reports[0].time * 1000000
        $ts = [TimeSpan]::FromSeconds([math]::Round(($endTimeUsecs - $startTimeUsecs) / 1000000))
        $duration = "{0}:{1:d2}:{2:d2}:{3:d2}" -f $ts.Days, $ts.Hours, $ts.Minutes, $ts.Seconds
        Write-Host "CFT job completion time: $duration" -foregroundcolor Green
        $24HourEstimate = [math]::Round((24 / $hoursApart) * $ts.TotalHours)
        Write-Host "Estimated job completion time for daily snapshots: $24HourEstimate hours"  -foregroundcolor Green
        exit
    }else{
        if(!$reportedWaiting){
            Write-Host "Waiting for CFT job to complete (wait or press CTRL-C to exit and re-run the script later to check status)..."
            $reportedWaiting = $True
        }
        Start-Sleep 15
    }
}
