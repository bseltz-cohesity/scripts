# usage: ./archiveOldSnapshots.ps1 -vip mycluster `
#                                  -username admin `
#                                  -domain local `
#                                  -vault S3 `
#                                  -jobName myjob1, myjob2
#                                  -olderThan 30 `
#                                  -ifExpiringAfter 30 `
#                                  -keepFor 365 `
#                                  -archive

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][array]$jobNames, # jobs to archive
    [Parameter(Mandatory = $True)][string]$vault, #name of archive target
    [Parameter()][string]$olderThan = 0, #archive snapshots older than x days
    [Parameter()][string]$ifExpiringAfter = 0, #do not archve if the snapshot is going to expire within x days
    [Parameter()][string]$keepFor = 0, #set archive retention to x days from original backup date
    [Parameter()][switch]$archive
)

# source the cohesity-api helper code
. ./cohesity-api

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

# olderThan days in usecs
$olderThanUsecs = timeAgo $olderThan days

# find specified jobs
$jobs = api get protectionJobs

foreach($jobname in $jobNames){
    $job = $jobs | Where-Object name -eq $jobname
    if($job){

        "searching for old $($job.name) snapshots..."

        # find local snapshots that are older than X days that have not been archived yet
        $runs = (api get protectionRuns?jobId=$($job.id)`&numRuns=999999`&runTypes=kRegular`&runTypes=kFull`&excludeTasks=true`&excludeNonRestoreableRuns=true) | `
            Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
            Where-Object { $_.copyRun[0].runStartTimeUsecs -le $olderThanUsecs } | `
            Where-Object { !('kArchival' -in $_.copyRun.target.type) -or ($_.copyRun | Where-Object { $_.target.type -eq 'kArchival' -and $_.status -in @('kCanceled','kFailed') }) } | `
            Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

        foreach ($run in $runs) {

            $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
            $jobName = $run.jobName

            $now = dateToUsecs $(get-date)

            # local snapshots stats
            $startTimeUsecs = $run.copyRun[0].runStartTimeUsecs
            $expireTimeUsecs = $run.copyRun[0].expiryTimeUsecs
            $daysToExpire = [math]::Round(($expireTimeUsecs - $now) / 86400000000)

            # calculate archive expire time
            if($keepFor -gt 0){
                $newExpireTimeUsecs = $startTimeUsecs + ([int]$keepFor * 86400000000)
            }else{
                $newExpireTimeUsecs = $expireTimeUsecs
            }
            $daysToKeep = [math]::Round(($newExpireTimeUsecs - $now) / 86400000000) 

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
                        'jobUid'            = $run.jobUid
                    }
                )
            }

            # If the Local Snapshot is not expiring soon...
            if ($daysToExpire -gt $ifExpiringAfter) {
                $newExpireDate = (get-date).AddDays($daysToKeep).ToString('yyyy-MM-dd')
                if ($archive) {
                    write-host "$($jobName): archiving $runDate until $newExpireDate" -ForegroundColor Green
                    # execute archive task if arcvhive swaitch is set
                    $null = api put protectionRuns $archiveTask
                }
                else {
                    # or just display what we would do if archive switch is not set
                    write-host "$($jobName): would archive $runDate until $newExpireDate" -ForegroundColor Green
                }
            }
            # otherwise tell us that we're not archiving since the snapshot is expiring soon
            else {
                write-host "$($jobName): skipping $runDate (expiring in $daysToExpire days)" -ForegroundColor Gray
            }
        }
    }else{
        # report job not found
        write-host "$($jobname): not found" -ForegroundColor Yellow
    }
}
