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

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true" # protectionJobs | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $false}

# $finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')
$finishedStates = @('Canceled', 'Succeeded', 'Failed', 'SucceededWithWarning')

$now = (Get-Date)
$nowUsecs = dateToUsecs $now

if($daysBack -gt 0){
    $daysBackUsecs = dateToUsecs ((Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-$daysBack))
    # $daysBackUsecs = timeAgo $daysBack days
}

$dailyCountStarted = @{}
$dailyCountFinished = @{}
$dailyCountRunning = @{}
$replications = @()

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $endUsecs = $nowUsecs
    Write-Host $job.name
    while($True){
        $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true"
        # $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&endTimeUsecs=$endUsecs&excludeTasks=true"
        foreach($run in $runs.runs){
            if($daysBack -gt 0 -and $run.localBackupInfo.startTimeUsecs -lt $daysBackUsecs){
                break
            }
            $runStartTime = usecsToDate $run.localBackupInfo.startTimeUsecs
            $runStartDate = $runStartTime.ToString('yyyy-MM-dd')
            if($runStartDate -notin $dailyCountFinished.Keys){
                $dailyCountFinished["$runStartDate"] = 0
            }
            if($runStartDate -notin $dailyCountRunning.Keys){
                $dailyCountRunning["$runStartDate"] = 0
            }
            if($runStartDate -notin $dailyCountStarted.Keys){
                $dailyCountStarted["$runStartDate"] = 0
            }
            foreach($copyRun in $run.replicationInfo.replicationTargetResults){
                $dailyCountStarted["$runStartDate"] += 1
                if($copyRun.status -in $finishedStates){
                    $dailyCountFinished["$runStartDate"] += 1
                    $endTime = usecsToDate $copyRun.endTimeUsecs
                    if($copyRun.status -eq 'kFailure'){
                        $endTime = $runStartTime
                    }
                }else{
                    $dailyCountRunning["$runStartDate"] += 1
                    $endTime = $now
                }
                $replications = @($replications + @{'startTime' = $runStartTime; 'endTime' = $endTime})
                Write-Host ("`t{0}`t{1}" -f $runStartTime, $copyRun.status)
            }
        }
        if($runs.Count -eq $numRuns){
            $endUsecs = $runs[-1].localBackupInfo.endTimeUsecs - 1
        }else{
            break
        }
    }
}

Write-Host "`n========================="
Write-Host "Replication tasks per day"
Write-Host "=========================`n"
$replications = $replications | ConvertTo-Json -Depth 99 | ConvertFrom-Json
$totalRunning = 0
foreach($thisDateString in ($dailyCountStarted.Keys | Sort-Object)){
    $totalRunning += $dailyCountRunning["$thisDateString"]
    $thisDate = [datetime]$thisDateString
    $wasRunning = @($replications | Where-Object {$_.startTime -lt $($thisDate.AddDays(1)) -and $_.endTime -ge $thisDate}).Count
    Write-Host "$thisDateString`t started: $($dailyCountStarted["$thisDateString"]) `t finished: $($dailyCountFinished["$thisDateString"])`t in queue (that day): $wasRunning`t in queue (now): $($dailyCountRunning["$thisDateString"])"
}
Write-Host "`nTotal Still Running:  $totalRunning"
