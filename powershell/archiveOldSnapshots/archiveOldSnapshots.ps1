### usage: ./archiveOldSnapshots.ps1 -vip mycluster -username admin [ -domain local ] -vault S3 -olderThan 365 [ -IfExpiringAfter 30 ] [ -keepFor 365 ] [ -archive ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$vault, #name of archive target
    [Parameter(Mandatory = $True)][string]$olderThan, #archive snapshots older than x days
    [Parameter()][string]$IfExpiringAfter = 0, #do not archve if the snapshot is going to expire within x days
    [Parameter()][string]$keepFor = 0, #set archive retention to x days from original backup date
    [Parameter()][switch]$archive
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$clusterId = (api get cluster).id

### get archive target info
$vaults = api get vaults | Where-Object { $_.name -eq $vault }
if (!$vaults) {
    Write-Warning "Archive Target $vault not found"
    exit
}
$vaultName = $vaults[0].name
$vaultId = $vaults[0].id

### olderThan days in usecs
$olderThanUsecs = timeAgo $olderThan days

### find protectionRuns with old local snapshots that are not archived yet and sort oldest to newest
"searching for old snapshots..."
foreach ($job in ((api get protectionJobs) | Where-Object{ $_.policyId.split(':')[0] -eq $clusterId })) {
    
    $runs = (api get protectionRuns?jobId=$($job.id)`&numRuns=999999`&runTypes=kRegular`&excludeTasks=true`&excludeNonRestoreableRuns=true) | `
        Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
        Where-Object { $_.copyRun[0].runStartTimeUsecs -le $olderThanUsecs } | `
        Where-Object { !('kArchival' -in $_.copyRun.target.type) } | `
        Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

    foreach ($run in $runs) {

        $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
        $jobName = $run.jobName

        ### calculate daysToKeep
        $startTimeUsecs = $run.copyRun[0].runStartTimeUsecs
        if($keepFor -gt 0){
            $expireTimeUsecs = $startTimeUsecs + ([int]$keepFor * 86400000000)
        }else{
            $expireTimeUsecs = $run.copyRun[0].expiryTimeUsecs
        }
        $now = dateToUsecs $(get-date)
        $daysToKeep = [math]::Round(($expireTimeUsecs - $now) / 86400000000) 

        ### create archive task definition
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

        ### If the Local Snapshot is not expiring soon...
        if ($daysToKeep -gt $IfExpiringAfter) {
            if ($archive) {
                write-host "Archiving $runDate  $jobName for $daysToKeep days" -ForegroundColor Green
                ### execute archive task if arcvhive swaitch is set
                $result = api put protectionRuns $archiveTask
            }
            else {
                ### just display what we would do if archive switch is not set
                write-host "$runDate  $jobName  (would archive for $daysToKeep days)" -ForegroundColor Green
            }
        }
        ### Otherwise tell us that we're not archiving since the snapshot is expiring soon
        else {
            write-host "$runDate  $jobName  (expiring in $daysToKeep days. skipping...)" -ForegroundColor Gray
        }
    }

}

