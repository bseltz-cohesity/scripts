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
    [Parameter()][array]$jobName, # jobs to archive
    [Parameter()][string]$jobList,
    [Parameter(Mandatory = $True)][string]$vault, #name of archive target
    [Parameter()][string]$olderThan = 0, #archive snapshots older than x days
    [Parameter()][string]$ifExpiringAfter = 0, #do not archve if the snapshot is going to expire within x days
    [Parameter()][string]$keepFor = 0, #set archive retention to x days from original backup date
    [Parameter()][switch]$archive,
    [Parameter()][switch]$fullOnly,
    [Parameter()][switch]$includeLogs,
    [Parameter()][array]$dates,
    [Parameter()][ValidateSet('kCloud','kTape','kNas')][string]$vaultType = 'kCloud'
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

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)

# get archive target info
$vaults = api get vaults | Where-Object { $_.name -eq $vault }  # ?includeFortKnoxVault=true
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
$runTypes = 'runTypes=kRegular&runTypes=kFull&'
if($fullOnly){
    $runTypes = 'runTypes=kFull&'
}
if($includeLogs){
    $runTypes = ''
}

$dontrunstates = @('kAccepted', 'kRunning', 'kCanceling', 'kSuccess')
$finishedStates = @('kSuccess', 'kWarning', 'kFailure')

foreach($jobName in $jobNames | Sort-Object -Unique){
    $theseJobs = $jobs | Where-Object name -eq $jobName
    if($theseJobs){
        foreach($job in $theseJobs){
            "searching for old $jobName snapshots..."

            # find local snapshots that are older than X days that have not been archived yet
            $runs = (api get "protectionRuns?jobId=$($job.id)&numRuns=999999&$($runTypes)excludeTasks=true&excludeNonRestoreableRuns=true") | `
                Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
                Where-Object { $_.copyRun[0].runStartTimeUsecs -le $olderThanUsecs } |
                Where-Object { $_.backupRun.status -in $finishedStates } |
                Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }
            
            foreach ($run in $runs) {
                
                $needsArchive = $True
                $alreadyArchived = $false
                $wouldExpire = $false
    
                foreach($copyRun in $run.copyRun){
                    if($copyRun.target.type -eq 'kArchival' -and
                           $copyRun.target.archivalTarget.vaultName -eq $vaultName -and
                           $copyRun.status -in $dontrunstates){
                       $needsArchive = $false
                       $alreadyArchived = $True
                    }
                }
    
                $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
                $runDateShort = ([datetime]$runDate).ToString("yyyy-MM-dd")
                if($dates.Length -eq 0 -or $runDateShort -in $dates){
                    # local snapshots stats
                    $now = dateToUsecs $(get-date)
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
        
                    if($daysToKeep -lt 1){
                        $needsArchive = $false
                        $wouldExpire = $True
                    }
        
                    if($needsArchive){
        
                        $thisrun = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$startTimeUsecs&excludeTasks=true&id=$($job.id)"
                        $jobUid = $thisrun.backupJobRuns.protectionRuns[0].backupRun.base.jobUid
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
                                    'runStartTimeUsecs' = $startTimeUsecs;
                                    'jobUid'            = @{
                                        "clusterId" = $jobUid.clusterId;
                                        "clusterIncarnationId" = $jobUid.clusterIncarnationId;
                                        "id" = $jobUid.objectId
                                    }
                                }
                            )
                        }
                        # If the Local Snapshot is not expiring soon...
                        if($dates.Length -eq 0 -or $runDateShort -in $dates){
                            if ($daysToExpire -gt $ifExpiringAfter) {
                                $newExpireDate = (get-date).AddDays($daysToKeep).ToString('yyyy-MM-dd')
                                if ($archive) {
                                    Write-Host "$($jobName): archiving $runDate until $newExpireDate" -ForegroundColor Green
                                    # execute archive task if arcvhive swaitch is set
                                    $null = api put protectionRuns $archiveTask
                                }
                                else {
                                    # or just display what we would do if archive switch is not set
                                    Write-Host "$($jobName): would archive $runDate until $newExpireDate" -ForegroundColor Green
                                }
                            }
                            # otherwise tell us that we're not archiving since the snapshot is expiring soon
                            else {
                                Write-Host "$($jobName): skipping $runDate (expiring in $daysToExpire days)" -ForegroundColor Gray
                            }
                        }
                    }else{
                        if($alreadyArchived){
                            Write-Host "$($jobName): $runDate already archived or archiving..." -ForegroundColor Magenta
                        }elseif($wouldExpire){
                            Write-Host "$($jobName): skipping $runDate (archive would expire $(-$daysToKeep) days ago)" -ForegroundColor Magenta
                        }
                    }
                }
            }
        }
    }else{
        # report job not found
        Write-Host "$($jobName): not found" -ForegroundColor Yellow
    }
}
