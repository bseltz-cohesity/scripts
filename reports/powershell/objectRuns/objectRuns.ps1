# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][int]$numRuns = 100,
    [Parameter()][int]$daysBack = 7,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'MiB'
)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

$endDate = Get-Date
$endDateUsecs = dateToUsecs $endDate
$startDateUsecs = dateToUsecs ($endDate.AddDays(-$daysBack))

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "objectRuns-$($cluster.name)-$dateString.csv"

# headings
"Job Name,Tenant,Object Type,Object Name,Run Date,Status,Logical $unit,$unit Read,$unit Written" | Out-File -FilePath $outfileName

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}


$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $endUsecs = dateToUsecs (Get-Date)
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        $tenant = $job.permissions.name
        if($tenant){
            "{0} ({1})" -f $job.name, $job.permissions.name  # tenant
        }else{
            "{0}" -f $job.name
        }
        while($True){
            $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true"
            if($runs.runs.Count -gt 0){
                $endUsecs = $runs.runs[-1].localBackupInfo.startTimeUsecs - 1
            }else{
                break
            }
            foreach($run in $runs.runs | Where-Object isLocalSnapshotsDeleted -ne $True){
                
                $runStartTimeUsecs = $run.localBackupInfo.startTimeUsecs
                if($runStartTimeUsecs -ge $startDateUsecs -and $runStartTimeUsecs -le $endDateUsecs){
                    $runStartTime = usecsToDate $runStartTimeUsecs
                    foreach($object in $run.objects){
                        $status = $object.localSnapshotInfo.snapshotInfo.status.subString(1)
                        $objectName = $object.object.name
                        $objectType = $object.object.objectType.subString(1)
                        "    {0}`t{1}`t{2}`t{3}" -f $objectName, $objectType, $runStartTime, $status
                        $stats = $object.localSnapshotInfo.snapshotInfo.stats
                        $logicalSizeBytes = ''
                        if($stats.PSObject.Properties['logicalSizeBytes']){
                            $logicalSizeBytes = $stats.logicalSizeBytes
                        }
                        $bytesRead = ''
                        if($stats.PSObject.Properties['bytesRead']){
                            $bytesRead = $stats.bytesRead
                        }
                        $bytesWritten = ''
                        if($stats.PSObject.Properties['bytesWritten']){
                            $bytesWritten = $stats.bytesWritten
                        }
                    }
                }
                # "Job Name,Tenant,Object Name,Run Date,Status,Logical $unit,$unit Read,$unit Written"
                """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}""" -f $job.name, $tenant, $objectType, $objectName, $runStartTime, $status, $(toUnits $logicalSizeBytes), $(toUnits $bytesRead), $(toUnits $bytesWritten) | Out-File -FilePath $outfileName -Append 
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
