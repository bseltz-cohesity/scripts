### usage: ./monitorArchiveTasks.ps1 -vip mycluster -username admin [ -domain local ] [ -olderThan 30 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][array]$jobNames,  # comma separated list of job names to include
    [Parameter()][switch]$allowReduction,  # if omitted, no shortening of retention will occur
    [Parameter()][string]$target, # optional target name
    [Parameter(Mandatory)][int64]$daysToKeep, #new retention (from backup date)
    [Parameter()][switch]$commit
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$cluster = api get cluster
$clusterId = $cluster.id
$modernVersion = $cluster.clusterSoftwareVersion -gt "6.5.1b"

# job selector
$jobs = api get protectionJobs
$policies = api get protectionPolicies

### find protectionRuns with old local snapshots with archive tasks and sort oldest to newest
"searching for archives..."

$jobs = api get protectionJobs

foreach ($job in $jobs | Sort-Object -Property name) {
    $jobName = $job.name
    if(!$jobNames -or $job.name -in $jobNames){
        $jobName
        $runs = (api get protectionRuns?jobId=$($job.id)`&excludeTasks=true`&excludeNonRestoreableRuns=true`&numRuns=999999`&runTypes=kRegular) | `
            Where-Object { 'kArchival' -in $_.copyRun.target.type } | `
            Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

        foreach ($run in $runs) {

            $localCopy = $run.copyRun | Where-Object {$_.target.type -eq 'kLocal'}
            $runDate = usecsToDate $localCopy.runStartTimeUsecs
            $localExpiry = $localCopy.expiryTimeUsecs
            if($localExpiry -gt (dateToUsecs (get-date)) -or $True -eq $modernVersion){

                foreach ($copyRun in $run.copyRun | Where-Object {$_.target.type -eq 'kArchival' -and $_.status -eq 'kSuccess'}) {
                    if ($copyRun.expiryTimeUsecs -gt 0) {
                        if( ! $target -or $copyRun.target.archivalTarget.vaultName -eq $target){
                            $startTimeUsecs = $copyRun.runStartTimeUsecs
                            $newExpireTimeUsecs = $startTimeUsecs + ($daysToKeep * 86400000000)
                            $currentExpireTimeUsecs = $copyRun.expiryTimeUsecs
                            $daysToExtend = [int64][math]::Round(($newExpireTimeUsecs - $currentExpireTimeUsecs) / 86400000000)
                            if(!($daysToExtend -lt 0) -or $allowReduction){
                                if($daysToExtend -ne 0){
                                    write-host "    $($runDate): adjusting by $daysToExtend day(s)" -ForegroundColor Green
                                    $expireRun = @{'jobRuns' = @(
                                            @{
                                                'jobUid'            = $run.jobUid;
                                                'runStartTimeUsecs' = $run.backupRun.stats.startTimeUsecs;
                                                'copyRunTargets'    = @(
                                                    @{'daysToKeep'       = $daysToExtend;
                                                        'type'           = 'kArchival';
                                                        'archivalTarget' = $copyRun.target.archivalTarget
                                                    }
                                                )
                                            }
                                        )
                                    }
                                    if ($commit) {
                                        $null = api put protectionRuns $expireRun
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
