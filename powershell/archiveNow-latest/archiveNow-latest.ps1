# usage: ./archiveNow-latest.ps1 -vip mycluster `
#                                -username admin `
#                                -domain local `
#                                -vault S3 `
#                                -vaultType kNas `
#                                -jobName myjob1, myjob2 `
#                                -keepFor 365 `
#                                -commit

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][array]$jobNames, # jobs to archive
    [Parameter(Mandatory = $True)][string]$vault, #name of archive target
    [Parameter(Mandatory = $True)][int]$keepFor, #set archive retention to x days from backup date
    [Parameter()][switch]$commit,
    [Parameter()][switch]$localOnly,
    [Parameter()][ValidateSet('kCloud','kTape','kNas')][string]$vaultType = 'kCloud',
    [Parameter()][switch]$fullOnly
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
$cluster = api get cluster
$jobs = api get protectionJobs
if($localOnly){
    $jobs = $jobs | Where-Object {$_.policyId.split(':')[0] -eq $cluster.id}
}

if($jobNames){
    $jobs = $jobs | Where-Object name -in $jobNames
}

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')

foreach($job in $jobs){

    $jobName = $job.name
    # find latest local snapshot
    $runs = (api get "protectionRuns?jobId=$($job.id)&numRuns=999&runTypes=kRegular&runTypes=kFull&excludeTasks=true") | `
        Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
        Where-Object { $_.backupRun.status -eq 'kSuccess' -or $_.backupRun.status -eq 'kWarning' } | `
        Where-Object {@($_.copyRun.status | Where-Object {$finishedStates -notcontains $_}).Count -eq 0} | `
        Where-Object { 'kArchival' -notin $_.copyRun.target.type } | ` 
        Sort-Object -Property {$_.copyRun[0].runStartTimeUsecs} -Descending
    if($fullOnly){
        $runs = $runs | Where-Object { $_.backupRun.runType -eq 'kFull' }
    }
    if($runs){
        $run = $runs[0]
        if($run){
            $now = dateToUsecs $(get-date)

            # local snapshots stats
            $startTimeUsecs = $run.copyRun[0].runStartTimeUsecs
            $expireTimeUsecs = $run.copyRun[0].expiryTimeUsecs
            $runDate = usecsToDate $startTimeUsecs
    
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
                                    'vaultType' = $vaultType
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
            if($commit){
                write-host "Archiving $($jobName) ($runDate) --> $vaultName ($expireDate)"
                $null = api put protectionRuns $archiveTask
            }else{
                write-host "Would archive $($jobName) ($runDate) --> $vaultName ($expireDate)"
            }
        }
    }
}
