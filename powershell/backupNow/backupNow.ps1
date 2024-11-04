# version 2024.07.08

# version history
# ===============
# 2023.01.10 - enforce sleeptimesecs >= 30 and waitForNewRunMinutes >= 12
# 2023.02.17 - implement retry on get protectionJobs - added error code 7
# 2023.03.29 - version bump
# 2023.04.11 - fixed bug in line 70 - last run is None error, added metafile check for new run
# 2023.04.13 - fixed log archiving bug
# 2023.04.14 - fixed metadatafile watch bug
# 2023.07.04 - added -dbg switch to output payload to payload.json file
# 2023.07.05 - updated payload to solve p11 error "TARGET_NOT_IN_POLICY_NOT_ALLOWED%!(EXTRA int64=0)"
# 2023-08-14 - updated script to exit with failure on "TARGET_NOT_IN_POLICY_NOT_ALLOWED" and added extended error code 8
# 2023-09-03 - added support for read replica, various optimizations and fixes, increased sleepTimeSecs to 360, increased waitForNewRunMinutes to 50
# 2023-09-06 - added -timeoutSec 300, -noCache, granular sleep times, interactive mode
# 2023-09-13 - improved error handling on start request, exit on kInvalidRequest
# 2023-11-20 - tighter API call to find protection job, monitor completion with progress API rather than runs API
# 2023-11-29 - fixed hang on object not in job run
# 2023-12-03 - version bump
# 2023-12-11 - Added Succeeded with Warning extended exit code 9
# 2023.12.13 - re-ordered auth parameters (to force first unnamed parameter to be interpreted as password)
# 2024.02.19 - expanded existing run string matches
# 2024.03.08 - refactored status monitor loop, added -quick mode
# 2024.05.17 - added support for EntraID (Open ID) authentication
# 2024.06.03 - fix unintended replication/archival
# 2024.07.08 - reintroduced --keepLocalFor functionality
#
# extended error codes
# ====================
# 0: Successful
# 1: Unsuccessful
# 2: connection/authentication error
# 3: Syntax Error
# 4: Timed out waiting for existing run to finish
# 5: Timed out waiting for status update
# 6: Timed out waiting for new run to appear
# 7: Timed out getting protection jobs
# 8: Target not in policy not allowed
# 9: Succeeded with Warnings

# process commandline arguments
[CmdletBinding(PositionalBinding=$False)]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # endpoint to connect to
    [Parameter()][string]$username = 'helios',  # username for authentication / password storage
    [Parameter()][string]$password = $null,  # send password / API key via command line (not recommended)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,         # use API key authentication
    [Parameter()][switch]$noPrompt,          # do not prompt for password
    [Parameter()][switch]$mcm,               # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,   # MFA code
    [Parameter()][switch]$emailMfaCode,      # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][string]$tenant,            # tenant org name
    [Parameter()][switch]$EntraId,           # use API key authentication
    [Parameter()][string]$vip2,              # alternate cluster to connect to (deprecated)
    [Parameter(Mandatory = $True)][string]$jobName,  # job to run
    [Parameter()][switch]$usePolicy,         # deprecated (does nothing)
    [Parameter()][switch]$localOnly,         # override policy - perform local backup only
    [Parameter()][switch]$noReplica,         # override policy - skip replication
    [Parameter()][switch]$noArchive,         # override policy - skip archival
    [Parameter()][string]$jobName2,          # alternate jobName to run (deprecated)
    [Parameter()][int]$keepLocalFor,         # override policy - keep local snapshot for x days
    [Parameter()][string]$replicateTo,       # override policy - remote cluster to replicate to
    [Parameter()][int]$keepReplicaFor,       # override policy - keep replica for x days
    [Parameter()][string]$archiveTo,         # override policy - target to archive to
    [Parameter()][int]$keepArchiveFor,       # override policy - keep archive for x days
    [Parameter()][switch]$enable,            # deprecated (does nothing)
    [Parameter()][ValidateSet('kRegular','kFull','kLog','kSystem','Regular','Full','Log','System')][string]$backupType = 'kRegular',
    [Parameter()][array]$objects,            # list of objects to include in run
    [Parameter()][switch]$progress,          # display progress percent
    [Parameter()][switch]$wait,              # wait for completion and report end status
    [Parameter()][string]$logfile,           # name of log file
    [Parameter()][switch]$outputlog,         # enable logging
    [Parameter()][string]$metaDataFile,      # backup file list
    [Parameter()][switch]$abortIfRunning,    # exit if job is already running
    [Parameter()][int64]$waitMinutesIfRunning = 60,     # give up and exit if existing run is still running
    [Parameter()][int64]$waitForNewRunMinutes = 50,     # give up and exit if new run fails to appear
    [Parameter()][int64]$cancelPreviousRunMinutes = 0,  # cancel previous run if it has been running long
    [Parameter()][int64]$statusRetries = 10,   # give up waiting for new run to appear
    [Parameter()][switch]$extendedErrorCodes,  # report failure-specific error codes
    [Parameter()][switch]$noCache,
    [Parameter()][int64]$sleepTimeSecs = 360,  # sleep seconds between status queries
    [Parameter()][int64]$startWaitTime = 60,
    [Parameter()][int64]$cacheWaitTime = 60,
    [Parameter()][int64]$retryWaitTime = 300,
    [Parameter()][int64]$timeoutSec = 300,
    [Parameter()][int64]$interactiveStartWaitTime = 15,
    [Parameter()][int64]$interactiveRetryWaitTime = 30,
    [Parameter()][switch]$interactive,
    [Parameter()][switch]$dbg,
    [Parameter()][switch]$quick
)

$cacheSetting = 'true'
if($noCache){
    $cacheSetting = 'false'
    $cacheWaitTime = 0
}

if($interactive){
    $cacheWaitTime = 0
    $startWaitTime = $interactiveStartWaitTime
    $retryWaitTime = $interactiveRetryWaitTime
}

# $payloadCache = @{}

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning', '3', '4', '5', '6', 'Canceled', 'Succeeded', 'Failed', 'SucceededWithWarning')

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# enforce sleep times
if($sleepTimeSecs -lt 30){
    $sleepTimeSecs = 30
}

if($waitForNewRunMinutes -lt 12){
    $waitForNewRunMinutes = 12
}

if($progress){
    $wait = $True
}

if($outputlog){
    if($logfile){
        $scriptlog = $logfile
    }else{
        $scriptlog = $(Join-Path -Path $PSScriptRoot -ChildPath 'log-backupNow.log')
    }
    "$(Get-Date): backupNow started" | Out-File -FilePath $scriptlog
}

# log function
function output($msg, [switch]$warn, [switch]$quiet){
    if(!$quiet){
        if($warn){
            Write-Host $msg -ForegroundColor Yellow
        }else{
            Write-Host $msg
        }
    }
    if($outputlog){
        $msg | Out-File -FilePath $scriptlog -Append
    }
}

if($outputlog){
    # log command line parameters
    "command line parameters:" | Out-File $scriptlog -Append
    $CommandName = $PSCmdlet.MyInvocation.InvocationName;
    $ParameterList = (Get-Command -Name $CommandName).Parameters;
    foreach ($Parameter in $ParameterList) {
        Get-Variable -Name $Parameter.Values.Name -ErrorAction SilentlyContinue | Where-Object name -ne 'password' | Out-File $scriptlog -Append
    }
}

if($cohesity_api.api_version -lt '2022.08.02'){
    output "This script requires cohesity-api.ps1 version 2022.08.02 or later" -warn
    if($extendedErrorCodes){
        exit 2
    }else{
        exit 1
    }
}

apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -entraIdAuthentication $EntraId -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

### select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        output "Please provide -clusterName when connecting through helios" -warn
        if($extendedErrorCodes){
            exit 2
        }else{
            exit 1
        }
    }
}

if($cohesity_api.last_api_error -ne 'OK' -and $null -ne $cohesity_api.last_api_error){
    output $cohesity_api.last_api_error -warn -quiet
    if($extendedErrorCodes){
        exit 2
    }else{
        exit 1
    }
}

if(!$cohesity_api.authorized){
    output "Not authenticated" -warn
    if($extendedErrorCodes){
        exit 2
    }else{
        exit 1
    }
}

# build list of sourceIds if specified
$sources = @{}

function getObjectId($objectName){
    $global:_object_id = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $objectName){
            $global:_object_id = $obj.protectionSource.id
            break
        }
        if($obj.name -eq $objectName){
            $global:_object_id = $obj.id
            break
        }
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object_id){
                    get_nodes $node
                }
            }
        }
    }
    
    foreach($source in $sources){
        if($null -eq $global:_object_id){
            get_nodes $source
        }
    }
    return $global:_object_id
}

function cancelRunningJob($v1JobId, $durationMinutes){
    if($durationMinutes -gt 0){
        $durationUsecs = $durationMinutes * 60000000
        $cancelTime = (dateToUsecs) - $durationUsecs
        $runningRuns = api get "protectionRuns?jobId=$($v1JobId)&numRuns=10&excludeTasks=true&useCachedData=$cacheSetting" -timeout $timeoutSec | Where-Object {$_.backupRun.status -notin $finishedStates}
        foreach($run in $runningRuns){
            if($run.backupRun.stats.startTimeUsecs -gt 0 -and $run.backupRun.stats.startTimeUsecs -le $cancelTime){
                $null = api post "protectionRuns/cancel/$($v1JobId)" @{ "jobRunId" = $run.backupRun.jobRunId } -timeout $timeoutSec
                output "Canceling previous job run"
            }
        }
    }
}

$backupTypeEnum = @{'Regular' = 'kRegular'; 'Full' = 'kFull'; 'Log' = 'kLog'; 'System' = 'kSystem'; 'kRegular' = 'kRegular'; 'kFull' = 'kFull'; 'kLog' = 'kLog'; 'kSystem' = 'kSystem';}
if($backupType -in $backupTypeEnum.Keys){
    $backupType = $backupTypeEnum[$backupType]
}

if($quick){
    $cacheWaitTime = 0
    $startWaitTime = 10
    $retryWaitTime = 10
    $sleepTimeSecs = 10
    $wait = $True
}

Start-Sleep $cacheWaitTime

# find the jobID
$jobs = $null
$jobRetries = 0
while(! $jobs){
    $jobs = api get -v2 "data-protect/protection-groups?names=$jobName&isActive=true&isDeleted=false&pruneSourceIds=true&pruneExcludedSourceIds=true&useCachedData=$cacheSetting" -timeout $timeoutSec
    if(! $jobs){
        $jobRetries += 1
        if($jobRetries -eq $statusRetries){
            output "Timed out getting Job!" -warn
            if($extendedErrorCodes){
                exit 7
            }else{
                exit 1
            }
        }else{
            Start-Sleep $retryWaitTime
        }
    }
}
$job = ($jobs.protectionGroups | Where-Object name -ieq $jobName)
if($job){
    $policyId = $job.policyId
    $v2JobId = $job.id
    $v1JobId = ($v2JobId -split ":")[2]
    $jobName = $job.name
    $environment = $job.environment
    if($environment -eq 'kPhysicalFiles'){
        $environment = 'kPhysical'
    }
    if($environment -notin ('kOracle', 'kSQL') -and $backupType -eq 'kLog'){
        output "BackupType kLog not applicable to $environment jobs" -warn
        if($extendedErrorCodes){
            exit 3
        }else{
            exit 1
        }
    }
    if($objects){
        $v1Job = api get "protectionJobs/$($v1JobId)?onlyReturnBasicSummary=true&useCachedData=$cacheSetting" -timeout $timeoutSec
        if($environment -in @('kOracle', 'kSQL')){
            $backupJob = api get "/backupjobs/$($v1JobId)?useCachedData=$cacheSetting" -timeout $timeoutSec
            $backupSources = api get "/backupsources?allUnderHierarchy=false&entityId=$($backupJob.backupJob.parentSource.id)&excludeTypes=5&useCachedData=$cacheSetting" -timeout $timeoutSec
        }elseif($environment -eq 'kVMware'){
            $sources = api get "protectionSources/virtualMachines?protected=true&useCachedData=$cacheSetting&vCenterId=$($v1Job.parentSourceId)" -timeout $timeoutSec
        }elseif($environment -match 'kAWS'){
            $sources = api get "protectionSources?environments=kAWS&useCachedData=$cacheSetting&id=$($v1Job.parentSourceId)" -timeout $timeoutSec
        }else{
            $sources = api get "protectionSources?environments=$environment&useCachedData=$cacheSetting&id=$($v1Job.parentSourceId)" -timeout $timeoutSec
        }
    }
}else{
    output "Job $jobName not found!" -warn
    if($extendedErrorCodes){
        exit 3
    }else{
        exit 1
    }
}

# handle SQL DB run now objects
$sourceIds = @()
$selectedSources = @()
if($objects){
    $runNowParameters = @()
    foreach($object in $objects){
        if($environment -eq 'kSQL' -or $environment -eq 'kOracle'){
            if($environment -eq 'kSQL'){
                $server, $instance, $db = $object.split('/')
            }else{
                $server, $db = $object.split('/')
            }
            $serverObject = $backupSources.entityHierarchy.children | Where-Object {$_.entity.displayName -eq $server}
            if($serverObject){
                $serverObjectId = $serverObject.entity.id
            }
            if($serverObjectId){
                if($serverObjectId -in $v1Job.sourceIds){
                    if(! ($runNowParameters | Where-Object {$_.sourceId -eq $serverObjectId})){
                        $runNowParameters += @{
                            "sourceId" = $serverObjectId;
                        }
                        $selectedSources = @($selectedSources + $serverObjectId)
                    }
                    if($instance -or $db){                  
                        if($environment -eq 'kOracle' -or $environment -eq 'kSQL'){
                            $runNowParameter = $runNowParameters | Where-Object {$_.sourceId -eq $serverObjectId}
                            if(! $runNowParameter.databaseIds){
                                $runNowParameter.databaseIds = @()
                            }
                            if($backupJob.backupJob.PSObject.Properties['backupSourceParams']){
                                $backupJobSourceParams = $backupJob.backupJob.backupSourceParams | Where-Object sourceId -eq $serverObjectId
                            }else{
                                $backupJobSourceParams = $null
                            }
                            $serverSource = $backupSources.entityHierarchy.children | Where-Object {$_.entity.id -eq $serverObjectId}
                            if($environment -eq 'kSQL'){
                                # SQL
                                $instanceSource = $serverSource.auxChildren | Where-Object {$_.entity.displayName -eq $instance}
                                $dbSource = $instanceSource.children | Where-Object {$_.entity.displayName -eq "$instance/$db"}
                                if($dbSource -and ( $null -eq $backupJobSourceParams -or $dbSource.entity.id -in $backupJobSourceParams.appEntityIdVec -or $instanceSource.entity.id -in $backupJobSourceParams.appEntityIdVec)){
                                    $runNowParameter.databaseIds = @($runNowParameter.databaseIds + $dbSource.entity.id)
                                }else{
                                    output "$object not protected by job $jobName" -warn
                                    if($extendedErrorCodes){
                                        exit 3
                                    }else{
                                        exit 1
                                    }
                                }
                            }else{
                                # Oracle
                                $dbSource = $serverSource.auxChildren | Where-Object {$_.entity.displayName -eq "$db"}
                                if($dbSource -and ( $null -eq $backupJobSourceParams -or $dbSource.entity.id -in $backupJobSourceParams.appEntityIdVec)){
                                    $runNowParameter.databaseIds = @($runNowParameter.databaseIds + $dbSource.entity.id)
                                }else{
                                    output "$object not protected by job $jobName" -warn
                                    if($extendedErrorCodes){
                                        exit 3
                                    }else{
                                        exit 1
                                    }
                                }
                            }
                        }else{
                            output "Job is Volume based. Can not selectively backup instances/databases" -warn
                            if($extendedErrorCodes){
                                exit 3
                            }else{
                                exit 1
                            }
                        }
                    }
                }else{
                    output "Server $server not protected by job $jobName" -warn
                    if($extendedErrorCodes){
                        exit 3
                    }else{
                        exit 1
                    }
                }
            }else{
                output "Server $server not found" -warn
                if($extendedErrorCodes){
                    exit 3
                }else{
                    exit 1
                }
            }
        }elseif($environment -eq 'kVMware'){
            $thisObject = $sources | Where-Object name -eq $object
            if($thisObject){
                $objectId = $thisObject.id
                $sourceIds += $objectId
                $selectedSources = @($selectedSources + $objectId)
            }else{
                output "Object $object not found" -warn
                if($extendedErrorCodes){
                    exit 3
                }else{
                    exit 1
                }
            }
        }else{
            $objectId = getObjectId $object
            if($objectId){
                $sourceIds += $objectId
                $selectedSources = @($selectedSources + $objectId)
            }else{
                output "Object $object not found" -warn
                if($extendedErrorCodes){
                    exit 3
                }else{
                    exit 1
                }
            }
        }
    }
}

$copyRunTargets = @()
if($keepLocalFor){
    $copyRunTargets = @(
        @{
            "type" = "kLocal";
            "daysToKeep" = $keepLocalFor
        }
    )
}

# retrieve policy settings
$policy = api get "protectionPolicies/$policyId" -timeout $timeoutSec

# replication
if((! $localOnly) -and (! $noReplica)){
    if($policy.PSObject.Properties['snapshotReplicationCopyPolicies'] -and (! $replicateTo)){
        foreach($replica in $policy.snapshotReplicationCopyPolicies){
            if(!($copyRunTargets | Where-Object {$_.replicationTarget.clusterName -eq $replica.target.clusterName})){
                $copyRunTargets = $copyRunTargets + @{
                    "daysToKeep"        = $replica.daysToKeep;
                    "replicationTarget" = $replica.target;
                    "type"              = "kRemote"
                }
                if($keepReplicaFor){
                    $copyRunTargets[-1].daysToKeep = $keepReplicaFor
                }
            }
        }
    }
}


# archival
if((! $localOnly) -and (! $noArchive) -and ($backupType -ne 'kLog' -or $environment -ne 'kSQL')){
    if($policy.PSObject.Properties['snapshotArchivalCopyPolicies'] -and (! $archiveTo)){
        foreach($archive in $policy.snapshotArchivalCopyPolicies){
            if(!($copyRunTargets | Where-Object {$_.archivalTarget.vaultName -eq $archive.target.vaultName})){
                $copyRunTargets = $copyRunTargets + @{
                    "archivalTarget" = $archive.target;
                    "daysToKeep"     = $archive.daysToKeep;
                    "type"           = "kArchival"
                }
                if($keepArchiveFor){
                    $copyRunTargets[-1].daysToKeep = $keepArchiveFor
                }
            }
        }
    }
}

# add replication target and retention
if((! $localOnly) -and (! $noReplica)){
    if ($replicateTo) {
        if(! $keepReplicaFor){
            output "-keepReplicaFor is required" -warn
            if($extendedErrorCodes){
                exit 3
            }else{
                exit 1
            }
        }
        $remote = api get remoteClusters -timeout $timeoutSec | Where-Object {$_.name -eq $replicateTo}
        if ($remote) {
            $copyRunTargets = $copyRunTargets + @{
                "daysToKeep"        = $keepReplicaFor;
                "replicationTarget" = @{
                    "clusterId"   = $remote.clusterId;
                    "clusterName" = $remote.name
                };
                "type"              = "kRemote"
            }
        }
        else {
            output "Remote Cluster $replicateTo not found!" -warn
            if($extendedErrorCodes){
                exit 3
            }else{
                exit 1
            }
        }
    }
}

# add archival target and retention
if((! $localOnly) -and (! $noArchive)){
    if($archiveTo){
        if(! $keepArchiveFor){
            output "-keepArchiveFor is required" -warn
            if($extendedErrorCodes){
                exit 3
            }else{
                exit 1
            }
        }
        $vault = api get vaults?includeFortKnoxVault=true -timeout $timeoutSec | Where-Object {$_.name -eq $archiveTo}
        if($vault){
            $copyRunTargets = $copyRunTargets + @{
                "archivalTarget" = @{
                "vaultId" = $vault.id;
                "vaultName" = $vault.name;
                "vaultType" = "kCloud"
                };
                "daysToKeep" = $keepArchiveFor;
                "type" = "kArchival"
            }
        }else{
            output "Archive target $archiveTo not found!" -warn
            if($extendedErrorCodes){
                exit 3
            }else{
                exit 1
            }
        }
    }
}

# Finalize RunProtectionJobParam object
$jobdata = @{
   "runType" = $backupType
   "copyRunTargets" = $copyRunTargets
   "usePolicyDefaults" = $True
}

if($localOnly -or $noArchive -or $noReplica){
    $jobdata['usePolicyDefaults'] = $false
}

# add sourceIds if specified
$useMetadataFile = $false
if($objects){
    if($environment -eq 'kSQL' -or $environment -eq 'kOracle'){
        $jobdata['runNowParameters'] = $runNowParameters
    }else{
        if($metaDataFile){
            $useMetadataFile = $True
            $jobdata['runNowParameters'] = @()
            foreach($sourceId in $sourceIds){
                $jobdata['RunNowParameters'] += @{'sourceId' = $sourceId; 'physicalParams' = @{'metadataFilePath' = $metaDataFile}}
            }
        }else{
            $jobdata['sourceIds'] = $sourceIds
        }
    }
}else{
    if($metaDataFile){
        output '-objects is required when using -metadataFile' -warn
        if($extendedErrorCodes){
            exit 3
        }else{
            exit 1
        }
    }
}

# get last run id
$runs = api get -v2 "data-protect/protection-groups/$v2JobId/runs?numRuns=1&includeObjectDetails=false&useCachedData=$cacheSetting" -timeout $timeoutSec
if($null -ne $runs -and $runs.PSObject.Properties['runs']){
    $runs = @($runs.runs)
}

$lastRunId = 1
$newRunId = 1
$lastRunUsecs = 1662164882000000
if($null -ne $runs -and $runs.Count -ne "0"){
    $newRunId = $lastRunId = $runs[0].protectionGroupInstanceId
    $lastRunUsecs = $runs[0].localBackupInfo.startTimeUsecs
}

# run job
if($dbg){
    $jobdata | ConvertTo-Json -Depth 99 | Out-File -FilePath 'payload.json'
}

if($backupType -ne 'kRegular'){
    $jobdata['usePolicyDefaults'] = $false
}

$result = api post ('protectionJobs/run/' + $v1JobId) $jobdata -timeout $timeoutSec -quiet
$reportWaiting = $True
$now = Get-Date
$waitUntil = $now.AddMinutes($waitMinutesIfRunning)
while($result -ne ""){
    $runError = $cohesity_api.last_api_error
    if(!($runError -match "Protection Group already has a run") -and !($runError -match "Backup job has an existing active backup run") -and !( $runError -match "Protection group can only have one active backup run at a time")){
        output $runError -warn
        if($runError -match "TARGET_NOT_IN_POLICY_NOT_ALLOWED"){
            if($extendedErrorCodes){
                exit 8
            }else{
                exit 1
            }
        }
        if($runError -match "KInvalidRequest"){
            if($extendedErrorCodes){
                exit 3
            }else{
                exit 1
            }
        }
    }else{
        if($cancelPreviousRunMinutes -gt 0){
            cancelRunningJob $v1JobId $cancelPreviousRunMinutes
        }
        if($reportWaiting){
            if($abortIfRunning){
                output "job is already running"
                exit 0
            }
            # output $runError
            output "Waiting for existing job run to finish..."
            $reportWaiting = $false
        }
    }

    if((Get-Date) -gt $waitUntil){
        output "Timed out waiting for existing run to finish" -warn
        if($extendedErrorCodes){
            exit 4
        }else{
            exit 1
        }
    }

    Start-Sleep $retryWaitTime
    $result = api post ('protectionJobs/run/' + $v1JobId) $jobdata -timeout $timeoutSec -quiet
}
output "Running $jobName..."

# wait for new job run to appear
if($wait -or $progress){
    $now = Get-Date
    $waitUntil = $now.AddMinutes($waitForNewRunMinutes)
    while($newRunId -le $lastRunId){
        if((Get-Date) -gt $waitUntil){
            output "Timed out waiting for new run to appear" -warn
            if($extendedErrorCodes){
                exit 6
            }else{
                exit 1
            }
        }
        Start-Sleep $startWaitTime
        if($selectedSources.Count -gt 0){
            $runs = api get -v2 "data-protect/protection-groups/$v2JobId/runs?numRuns=10&includeObjectDetails=true&useCachedData=$cacheSetting&startTimeUsecs=$lastRunUsecs" -timeout $timeoutSec
            if($null -ne $runs -and $runs.PSObject.Properties['runs']){
                $runs = @($runs.runs | Where-Object {$selectedSources[0] -in $_.objects.object.id -or ! $_.objects})
            }
        }else{
            $runs = api get -v2 "data-protect/protection-groups/$v2JobId/runs?numRuns=1&includeObjectDetails=false&useCachedData=$cacheSetting&startTimeUsecs=$lastRunUsecs" -timeout $timeoutSec
            if($null -ne $runs -and $runs.PSObject.Properties['runs']){
                $runs = @($runs.runs)
            }
        }
        if($runs.PSObject.Properties['runs']){
            $runs = @($runs.runs)
        }
        $runs = $runs | Where-Object protectionGroupInstanceId -gt $lastRunId
        if($null -ne $runs -and $runs.Count -ne "0" -and $useMetadataFile -eq $True){
            foreach($run in $runs){
                $runDetail = api get "/backupjobruns?exactMatchStartTimeUsecs=$($run.localBackupInfo.startTimeUsecs)&id=$($v1JobId)&useCachedData=$cacheSetting" -timeout $timeoutSec
                $metadataFilePath = $runDetail[0].backupJobRuns.protectionRuns[0].backupRun.additionalParamVec[0].physicalParams.metadataFilePath
                if($metadataFilePath -eq $metaDataFile){
                    $newRunId = $run.protectionGroupInstanceId
                    $v2RunId = $run.id
                    break
                }
            }
        }elseif($null -ne $runs -and $runs.Count -ne "0"){
            $newRunId = $runs[0].protectionGroupInstanceId
            $v2RunId = $runs[0].id
        }
        if($newRunId -gt $lastRunId){
            $run = $runs[0]
            break
        }
    }
    output "New Job Run ID: $v2RunId"
}

# wait for job run to finish
if($wait -or $progress){
    $statusRetryCount = 0
    $lastProgress = -1
    $lastStatus = 'unknown'
    while ($lastStatus -notin $finishedStates){
        Start-Sleep $sleepTimeSecs
        $bumpStatusCount = $false
        try {
            if($run){
                if($run.PSObject.Properties['localBackupInfo']){
                    if($run.localBackupInfo.PSObject.Properties['status']){
                        $lastStatus = $run.localBackupInfo.status
                        $statusRetryCount = 0
                    }
                }else{
                    $bumpStatusCount = $True
                }
                if($lastStatus -in $finishedStates){
                    break
                }
                # display progress
                if($progress){
                    try{
                        if($run.localBackupInfo.PSObject.Properties['progressTaskId']){
                            $progressPath = $run.localBackupInfo.progressTaskId
                            $progressMonitor = api get "/progressMonitors?taskPathVec=$progressPath&excludeSubTasks=true&includeFinishedTasks=false&useCachedData=$cacheSetting" -timeout $timeoutSec
                            $percentComplete = $progressMonitor.resultGroupVec[0].taskVec[0].progress.percentFinished
                            $percentComplete = [math]::Round($percentComplete, 0)
                        }
                        if($percentComplete -ne $lastProgress){
                            "$percentComplete percent complete"
                            $lastProgress = $percentComplete
                        }
                    }catch{
                        # do nothing
                    }
                }
            }else{
                $bumpStatusCount = $True
            }
        }catch{
            $bumpStatusCount = $True
        }
        if($bumpStatusCount -eq $True){
            $statusRetryCount += 1
        }
        if($statusRetryCount -gt $statusRetries){
            output "Timed out waiting for status update" -warn
            if($extendedErrorCodes){
                exit 5
            }else{
                exit 1
            }
        }
        $run = api get -v2 "data-protect/protection-groups/$v2JobId/runs/$($v2RunId)?includeObjectDetails=false&useCachedData=$cacheSetting" -timeout $timeoutSec
    }
}

$statusMap = @('0', '1', '2', 'Canceled', 'Succeeded', 'Failed', 'SucceededWithWarning')

if($wait -or $progress){
    if($run.localBackupInfo.status -in @('3', '4', '5', '6')){
        $run.localBackupInfo.status = $statusMap[$run.localBackupInfo.status]
    }
    output "Job finished with status: $($run.localBackupInfo.status)"
    if($outputlog){
        "Backup ended $(usecsToDate $run.localBackupInfo.endTimeUsecs)" | Out-File -FilePath $scriptlog -Append
    }
    if($run.localBackupInfo.status -eq 'Succeeded'){
        exit 0
    }elseif($run.localBackupInfo.status -eq 'SucceededWithWarning'){
        if($run.PSObject.Properties['localBackupInfo'] -and $run.localBackupInfo.PSObject.Properties['messages'] -and $run.localBackupInfo.messages.Count -gt 0){
            output "Warning: $($run.localBackupInfo.messages[0])"
        }
        if($extendedErrorCodes){
            exit 9
        }else{
            exit 0
        }
    }else{
        if($run.localBackupInfo.status -eq 'Failed'){
            output "Error: $($run.localBackupInfo.messages[0])"
        }
        exit 1
    }
}

exit 0
