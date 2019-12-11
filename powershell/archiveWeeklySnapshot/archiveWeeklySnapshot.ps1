# usage: ./archiveWeeklySnapshot.ps1 -vip mycluster `
#                                    -username myuser `
#                                    -domain mydomain.net `
#                                    -jobNames 'SQL Backup', 'VM Backup' `
#                                    -vault s3 `
#                                    -dayOfWeek Sunday `
#                                    -keepFor 180

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][array]$jobNames, # jobs to archive
    [Parameter(Mandatory = $True)][string]$vault, # name of archive target
    [Parameter()][int32]$newerThan = 6, # don't process spanshots older than X days
    [Parameter(Mandatory = $True)][ValidateSet('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')][string]$dayOfWeek, 
    [Parameter()][string]$keepFor = 0, # set archive retention to x days from original backup date
    [Parameter()][switch]$archive # if excluded script will run in test run mode and will not archive
)

# start logging
$logfile = $(Join-Path -Path $PSScriptRoot -ChildPath log-archiveWeeklySnapshot.txt)
"`nScript Run: $(Get-Date)" | Out-File -FilePath $logfile -Append

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get archive target info
$vaults = api get vaults | Where-Object { $_.name -eq $vault }
if (!$vaults) {
    "  Archive Target $vault not found" | Tee-Object -FilePath $logfile -Append | Write-Host -ForegroundColor Yellow
    exit
}
$vaultName = $vaults[0].name
$vaultId = $vaults[0].id

# find specified jobs
$jobs = api get protectionJobs

foreach($jobname in $jobNames){
    $job = $jobs | Where-Object name -eq $jobname
    if($job){
        # find available runs that are newer than X days and are from the specified day of week
        $runs = api get "protectionRuns?jobId=$($job.id)&runTypes=kRegular&runTypes=kFull&excludeTasks=true&excludeNonRestoreableRuns=true&startTimeUsecs=$(timeAgo $newerThan days)" | `
            Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
            Where-Object { (usecsToDate ($_.copyRun[0].runStartTimeUsecs)).DayOfWeek -eq $dayOfWeek} | `
            Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }
        if($runs){
            # make sure no runs have been already archived
            $archivedRuns = $runs | Where-Object { ('kArchival' -in $_.copyRun.target.type) -and ($_.copyRun | Where-Object { $_.target.type -eq 'kArchival' -and $_.status -notin @('kCanceled','kFailed') }) }
            if($archivedRuns.length -eq 0){
                # select the first run to archive
                $run = $runs[0]
                # calculate daysToKeep
                $startTimeUsecs = $run.copyRun[0].runStartTimeUsecs
                if($keepFor -gt 0){
                    $expireTimeUsecs = $startTimeUsecs + ([int]$keepFor * 86400000000)
                }else{
                    $expireTimeUsecs = $run.copyRun[0].expiryTimeUsecs
                }
                $now = dateToUsecs $(get-date)
                $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
                $daysToKeep = [math]::Round(($expireTimeUsecs - $now) / 86400000000) 

                # archive params
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
                if ($archive) {
                    # archive the snapshot
                    "  $($job.name): Archiving ($runDate) for $daysToKeep days" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
                    $null = api put protectionRuns $archiveTask
                }
                else {
                    # display only (test run)
                    "  $($job.name): Would archive ($runDate) for $daysToKeep days" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
                }
            }else{
                # report already archived
                "  $($job.name): Already archived" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
            }
        }else{
            # report no run found
            "  $($job.name): No $dayOfWeek runs found in the past $newerThan days" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Yellow
        }
    }else{
        # report job not found
        "  $($jobName): Job not found" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Yellow
    }
}
