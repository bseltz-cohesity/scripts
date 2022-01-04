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
    [Parameter()][switch]$deleteSnapshots
)

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

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# outfile
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "log-deleteProtectionJob-$dateString.txt"

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"

$notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
if($notfoundJobs){
    Write-Host "Jobs not found: $($notfoundJobs -join ', ')" -ForegroundColor Yellow
    exit 1
}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    if($job.name -in $jobNames){
        if($deleteSnapshots){
            "DELETING JOB: $($job.name) (and deleting existing snapshots)" | Tee-Object -FilePath $outfileName -Append
            $null = api delete -v2 "data-protect/protection-groups/$($job.id)?deleteSnapshots=true"
        }else{
            "DELETING JOB: $($job.name) (but retaining existing snapshots)" | Tee-Object -FilePath $outfileName -Append
            $null = api delete -v2 "data-protect/protection-groups/$($job.id)?deleteSnapshots=false"
        }
    }
}

"`nOutput saved to $outfilename`n"
