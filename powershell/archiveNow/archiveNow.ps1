# usage: ./archiveOldSnapshots.ps1 -vip mycluster `
#                                  -username admin `
#                                  -domain local `
#                                  -vault S3 `
#                                  -jobName myjob1, myjob2
#                                  -keepFor 365

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][array]$jobNames, # jobs to archive
    [Parameter(Mandatory = $True)][string]$vault, #name of archive target
    [Parameter()][int]$keepFor #set archive retention to x days from backup date
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get archive target info
$vaults = api get vaults | Where-Object { $_.name -eq $vault }
if (!$vaults) {
    Write-Warning "Archive Target $vault not found"
    exit
}
$vaultName = $vaults[0].name
$vaultId = $vaults[0].id

# find specified jobs
$jobs = api get protectionJobs

foreach($jobname in $jobNames){
    $job = $jobs | Where-Object name -eq $jobname
    if($job){

        # find latest local snapshot that has not been archived yet
        $runs = (api get protectionRuns?jobId=$($job.id)`&numRuns=1`&runTypes=kRegular`&runTypes=kFull`&excludeTasks=true`&excludeNonRestoreableRuns=true) | `
            Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
            Where-Object { !('kArchival' -in $_.copyRun.target.type) -or ($_.copyRun | Where-Object { $_.target.type -eq 'kArchival' -and $_.status -in @('kCanceled','kFailed') }) } | `
            Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

        foreach ($run in $runs) {
            $jobName = $run.jobName
            $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
            $now = dateToUsecs $(get-date)

            # local snapshots stats
            $startTimeUsecs = $run.copyRun[0].runStartTimeUsecs
            $expireTimeUsecs = $run.copyRun[0].expiryTimeUsecs

            # get jobUid of originating cluster
            $runDetail = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$startTimeUsecs&excludeTasks=true&id=$($run.jobId)"
            $jobUid = $runDetail[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid

            # calculate archive expire time
            if($keepFor){
                $newExpireTimeUsecs = $startTimeUsecs + ([int]$keepFor * 86400000000)
            }else{
                $newExpireTimeUsecs = $expireTimeUsecs
            }
            $daysToKeep = [math]::Round(($newExpireTimeUsecs - $now) / 86400000000) 
            $expireDate = usecsToDate $newExpireTimeUsecs

            # create archive task definition
            $archiveTask = @{
                'jobRuns' = @(
                    @{
                        'copyRunTargets'    = @(
                            @{
                                'archivalTarget' = @{
                                    'vaultId'   = $vaultId;
                                    'vaultName' = $vaultName;
                                    'vaultType' = 'kCloud'
                                };
                                'daysToKeep'     = [int] $daysToKeep;
                                'type'           = 'kArchival'
                            }
                        );
                        'runStartTimeUsecs' = $run.copyRun[0].runStartTimeUsecs;
                        'jobUid'            = @{
                            'clusterId' = $jobUid.clusterId;
                            'clusterIncarnationId' = $jobUid.clusterIncarnationId;
                            'id' = $jobUid.objectId
                        }
                    }
                )
            }
            # submit the archive task
            write-host "$($jobName) ($runDate) --> $vaultName ($expireDate)"
            $null = api put protectionRuns $archiveTask
        }
    }else{
        # report job not found
        write-host "$($jobname): not found" -ForegroundColor Yellow
    }
}
