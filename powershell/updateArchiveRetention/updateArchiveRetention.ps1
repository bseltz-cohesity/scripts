### usage: ./monitorArchiveTasks.ps1 -vip mycluster -username admin [ -domain local ] [ -olderThan 30 ]

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
    [Parameter()][array]$jobNames,
    [Parameter()][array]$policyNames,
    [Parameter()][switch]$allowReduction,  # if omitted, no shortening of retention will occur
    [Parameter()][string]$target, # optional target name
    [Parameter(Mandatory)][int64]$daysToKeep, #new retention (from backup date)
    [Parameter()][switch]$commit
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

### cluster Id
$cluster = api get cluster
$clusterId = $cluster.id

# job selector
$jobs = api get protectionJobs
$policies = api get protectionPolicies

### find protectionRuns with old local snapshots with archive tasks and sort oldest to newest
"searching for archives..."

$jobs = api get protectionJobs

foreach ($job in $jobs | Sort-Object -Property name) {
    $policy = $policies | Where-Object {$_.id -eq $job.policyId}
    if(!$policyNames -or ($policy -and $policy.name -in $policyNames)){
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
                # if($localExpiry -gt (dateToUsecs (get-date))){
                    foreach ($copyRun in $run.copyRun | Where-Object {$_.target.type -eq 'kArchival' -and $_.status -eq 'kSuccess'}) {
                        if ($copyRun.expiryTimeUsecs -gt (dateToUsecs)) {
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
                                                        @{
                                                            'daysToKeep'     = $daysToExtend;
                                                            'type'           = 'kArchival';
                                                            'archivalTarget' = $copyRun.target.archivalTarget
                                                        }
                                                    )
                                                }
                                            )
                                        }
                                        # $expireRun | ConvertTo-Json -Depth 99
                                        if ($commit) {
                                            $null = api put protectionRuns $expireRun
                                        }
                                    }
                                }
                            }
                        }
                    }
                # }
            }
        }
    }
}
