### usage: ./monitorArchiveTasks.ps1 -vip mycluster -username admin [ -domain local ] [ -olderThan 30 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][string]$jobName, # optional jobName 
    [Parameter()][string]$target, # optional target name
    [Parameter()][int]$olderThan = 0, # expire archives older than x days
    [Parameter()][int]$newerThan = 0, # expire archives newer than X days
    [Parameter()][switch]$expire,
    [Parameter()][switch]$showUnsuccessful,
    [Parameter()][switch]$skipFirstOfMonth,
    [Parameter()][int]$numRuns = 1000
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$olderThanUsecs = timeAgo $olderThan days
$newerThanUsecs = timeAgo $newerThan days
$nowUsecs = timeAgo 1 second

Write-Host "searching for old archives..."

$jobs = api get protectionJobs
if($jobName){
    $jobs = $jobs | Where-Object name -eq $jobName
}

foreach ($job in $jobs) {
    $endUsecs = $olderThanUsecs
    Write-Host $job.name
    while($True){
        $runs = api get "protectionRuns?jobId=$($job.id)&excludeTasks=true&excludeNonRestoreableRuns=true&numRuns=$numRuns&endTimeUsecs=$endUsecs"
        $runCount = $runs.Count
        $runs = $runs | Where-Object { $_.copyRun[0].runStartTimeUsecs -le $olderThanUsecs } | `
                        Where-Object { 'kArchival' -in $_.copyRun.target.type } | `
                        Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

        if($newerThan -gt 0){
            $runs = $runs | Where-Object { $_.copyRun[0].runStartTimeUsecs -ge $newerThanUsecs }
        }

        foreach ($run in $runs) {

            $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
            $jobName = $run.jobName
            if(! $skipFirstOfMonth -or $runDate.Day -ne 1){
                foreach ($copyRun in $run.copyRun) {
                    if ($copyRun.target.type -eq 'kArchival') {
                        if (($copyRun.status -eq 'kSuccess' -or $copyRun.status -eq 4) -and (! $showUnsuccessful)) {
                            if ($copyRun.expiryTimeUsecs -gt $nowUsecs) {
                                if( ! $target -or $copyRun.target.archivalTarget.vaultName -eq $target){
                                    Write-Host "$runDate  $jobName" -ForegroundColor Green
                                    $expireRun = @{'jobRuns' = @(
                                            @{  'jobUid'            = $run.jobUid;
                                                'runStartTimeUsecs' = $run.backupRun.stats.startTimeUsecs;
                                                'copyRunTargets'    = @(
                                                    @{'daysToKeep'       = 0;
                                                        'type'           = 'kArchival';
                                                        'archivalTarget' = $copyRun.target.archivalTarget
                                                    }
                                                )
                                            }
                                        )
                                    }
                                    if ($expire) {
                                        $null = api put protectionRuns $expireRun
                                    }
                                }
                            }
                        }else{
                            if($copyRun.status -ne 'kSuccess' -and $showUnsuccessful){
                                Write-Host "$runDate  $jobName $($copyRun.status)" -ForegroundColor Yellow
                            }
                        }
                    }
                }
            }
        }
        if($runCount -eq $numRuns){
            $endUsecs = $runs[-1].backupRun.stats.endTimeUsecs - 1
        }else{
            break
        }
    }
}
