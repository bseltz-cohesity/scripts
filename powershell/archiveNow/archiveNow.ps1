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
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$jobName, # jobs to archive
    [Parameter()][string]$jobList,
    [Parameter(Mandatory = $True)][string]$vault, #name of archive target
    [Parameter()][int]$keepFor, #set archive retention to x days from backup date
    [Parameter()][switch]$commit,
    [Parameter()][switch]$localOnly,
    [Parameter()][ValidateSet('kCloud','kTape','kNas')][string]$vaultType = 'kCloud',
    [Parameter()][switch]$fullOnly,
    [Parameter()][int]$numRuns = 20
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

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

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

if($localOnly){
    $jobs = api get "protectionJobs?isDeleted=false&isActive=true"
}else{
    $jobs = api get "protectionJobs?isDeleted=false"
}

if($jobNames){
    $jobs = $jobs | Where-Object name -in $jobNames
}

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')

foreach($job in $jobs | Sort-Object -Property name){

    $jobName = $job.name
    # find latest local snapshot
    $runs = (api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&runTypes=kRegular&runTypes=kFull&excludeTasks=true&excludeNonRestorableRuns=true") | `
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
