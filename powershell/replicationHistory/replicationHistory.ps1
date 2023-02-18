### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][int]$numRuns = 1000,
    [Parameter()][int]$daysBack = 0
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$jobs = api get protectionJobs | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $false}

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')

$nowUsecs = dateToUsecs (get-date)

if($daysBack -gt 0){
    $daysBackUsecs = timeAgo $daysBack days
}

$dailyCount = @{}

foreach($job in $jobs | Sort-Object -Property name){
    $endUsecs = dateToUsecs (Get-Date)
    Write-Host $job.name
    while($True){
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&endTimeUsecs=$endUsecs&excludeTasks=true"
        foreach($run in $runs){
            if($daysBack -gt 0 -and $run.backupRun.stats.startTimeUsecs -lt $daysBackUsecs){
                break
            }
            $runStartTime = usecsToDate $run.backupRun.stats.startTimeUsecs
            $runStartDate = $runStartTime.ToString('yyyy-MM-dd')
            if($runStartDate -notin $dailyCount.Keys){
                $dailyCount["$runStartDate"] = 0
            }
            foreach($copyRun in $run.copyRun){
                $dailyCount["$runStartDate"] += 1
                if($copyRun.target.type -eq 'kRemote'){
                    Write-Host ("`t{0}`t{1}" -f $runStartTime, $copyRun.status)
                }
            }
        }
        if($runs.Count -eq $numRuns){
            $endUsecs = $runs[-1].backupRun.stats.endTimeUsecs - 1
        }else{
            break
        }
    }
}

Write-Host "`n========================="
Write-Host "Replication tasks per day"
Write-Host "=========================`n"
foreach($thisDate in ($dailyCount.Keys | Sort-Object)){
    Write-Host "$thisDate`t$($dailyCount["$thisDate"])"
}
Write-Host ""
