# version 2022.09.13

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # endpoint to connect to
    [Parameter()][string]$username = 'helios',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,         # use API key authentication
    [Parameter()][string]$password = $null,  # send password / API key via command line (not recommended)
    [Parameter()][switch]$noPrompt,          # do not prompt for password
    [Parameter()][switch]$mcm,               # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,   # MFA code
    [Parameter()][switch]$emailMfaCode,      # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][string]$tenant,            # tenant org name
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
    [Parameter()][int64]$waitForNewRunMinutes = 10,     # give up and exit if new run fails to appear
    [Parameter()][int64]$cancelPreviousRunMinutes = 0,  # cancel previous run if it has been running long
    [Parameter()][int64]$statusRetries = 10,   # give up waiting for new run to appear
    [Parameter()][switch]$extendedErrorCodes,  # report failure-specific error codes
    [Parameter()][int64]$sleepTimeSecs = 30    # sleep seconds between status queries
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# extended error codes
# ====================
# 0: Successful
# 1: Unsuccessful
# 2: connection/authentication error
# 3: Syntax Error
# 4: Timed out waiting for existing run to finish
# 5: Timed out waiting for status update
# 6: Timed out waiting for new run to appear

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

apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

function cancelRunningJob($job, $durationMinutes){
    if($durationMinutes -gt 0){
        $durationUsecs = $durationMinutes * 60000000
        $cancelTime = (dateToUsecs) - $durationUsecs
        $runningRuns = api get "protectionRuns?jobId=$($job.id)&numRuns=10&excludeTasks=true" | Where-Object {$_.backupRun.status -notin $finishedStates}
        foreach($run in $runningRuns){
            if($run.backupRun.stats.startTimeUsecs -gt 0 -and $run.backupRun.stats.startTimeUsecs -le $cancelTime){
                $null = api post "protectionRuns/cancel/$($job.id)" @{ "jobRunId" = $run.backupRun.jobRunId }
                output "Canceling previous job run"
            }
        }
    }
}

$backupTypeEnum = @{'Regular' = 'kRegular'; 'Full' = 'kFull'; 'Log' = 'kLog'; 'System' = 'kSystem'; 'kRegular' = 'kRegular'; 'kFull' = 'kFull'; 'kLog' = 'kLog'; 'kSystem' = 'kSystem';}
if($backupType -in $backupTypeEnum.Keys){
    $backupType = $backupTypeEnum[$backupType]
}

# get cluster id
$cluster = api get cluster

# find the jobID
$job = (api get protectionJobs | Where-Object name -ieq $jobName)
if($job){
    $policyId = $job.policyId
    if($policyId.split(':')[0] -ne $cluster.id){
        output "Job $jobName is not local to the cluster $($cluster.name)" -warn
        if($extendedErrorCodes){
            exit 3
        }else{
            exit 1
        }
    }
    $jobID = $job.id
    $environment = $job.environment
    if($environment -eq 'kPhysicalFiles'){
        $environment = 'kPhysical'
    }
    if($objects -and $environment -in @('kOracle', 'kSQL')){
        $backupJob = api get "/backupjobs/$jobID"
        $backupSources = api get "/backupsources?allUnderHierarchy=false&entityId=$($backupJob.backupJob.parentSource.id)&excludeTypes=5&includeVMFolders=true"    
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
        if($environment -match 'kAWS'){
            $sources = api get "protectionSources?environments=kAWS"
        }else{
            $sources = api get "protectionSources?environments=$environment"
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
            $serverObjectId = getObjectId $server
            if($serverObjectId){
                if($serverObjectId -in $job.sourceIds){
                    if(! ($runNowParameters | Where-Object {$_.sourceId -eq $serverObjectId})){
                        $runNowParameters += @{
                            "sourceId" = $serverObjectId;
                        }
                        $selectedSources = @($selectedSources + $serverObjectId)
                    }
                    if($instance -or $db){                  
                        if($environment -eq 'kOracle' -or $environment -eq 'kSQL'){ # $job.environmentParameters.sqlParameters.backupType -in @('kSqlVSSFile', 'kSqlNative')
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

# get last run id
if($selectedSources.Count -gt 0){
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&sourceId=$($selectedSources[0])"
    if(!$runs -or $runs.Count -eq 0){
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&excludeTasks=true"
    }
}else{
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&excludeTasks=true"
}

if($runs){
    $newRunId = $lastRunId = $runs[0].backupRun.jobRunId
}else{
    $newRunId = $lastRunId = 0
}

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning', '3', '4', '5', '6')

# set local retention
$copyRunTargets = @(
    @{
        "type" = "kLocal";
        "daysToKeep" = $keepLocalFor
    }
)

# retrieve policy settings
$policy = api get "protectionPolicies/$policyId"
if(! $keepLocalFor){
    $copyRunTargets[0].daysToKeep = $policy.daysToKeep
}

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
if((! $localOnly) -and (! $noArchive)){
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
        $remote = api get remoteClusters | Where-Object {$_.name -eq $replicateTo}
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
        $vault = api get vaults | Where-Object {$_.name -eq $archiveTo}
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
}

# add sourceIds if specified
if($objects){
    if($environment -eq 'kSQL' -or $environment -eq 'kOracle'){ # -and $job.environmentParameters.sqlParameters.backupType -in @('kSqlVSSFile', 'kSqlNative')
        $jobdata['runNowParameters'] = $runNowParameters
    }else{
        if($metaDataFile){
            $jobdata['runNowParameters'] = @()
            foreach($sourceId in $sourceIds){
                $jobdata['RunNowParameters'] += @{'sourceId' = $sourceId; 'physicalParams' = @{'metadataFilePath' = $metaDataFile}}
            }
        }else{
            $jobdata['sourceIds'] = $sourceIds
        }
    }
}

# run job
$result = api post ('protectionJobs/run/' + $jobID) $jobdata
$reportWaiting = $True
$now = Get-Date
$startUsecs = dateToUsecs $now
$waitUntil = $now.AddMinutes($waitMinutesIfRunning)
while($result -ne ""){
    if((Get-Date) -gt $waitUntil){
        output "Timed out waiting for existing run to finish" -warn
        if($extendedErrorCodes){
            exit 4
        }else{
            exit 1
        }
    }
    if($cancelPreviousRunMinutes -gt 0){
        cancelRunningJob $job $cancelPreviousRunMinutes
    }
    if($reportWaiting){
        if($abortIfRunning){
            output "job is already running"
            exit 0
        }
        output "Waiting for existing job run to finish..."
        $reportWaiting = $false
    }
    Start-Sleep $sleepTimeSecs
    $result = api post ('protectionJobs/run/' + $jobID) $jobdata -quiet
}
output "Running $jobName..."

# wait for new job run to appear
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
    Start-Sleep 3
    if($selectedSources.Count -gt 0){
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10&sourceId=$($selectedSources[0])"
    }else{
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10&excludeTasks=true"
    }
    $newRunId = $runs[0].backupRun.jobRunId
    if($newRunId -le $lastRunId){
        Start-Sleep $sleepTimeSecs
    }
}
output "New Job Run ID: $newRunId"

# wait for job run to finish
if($wait -or $progress){
    $statusRetryCount = 0
    $lastProgress = -1
    $lastStatus = 'unknown'
    while ($lastStatus -notin $finishedStates){
        Start-Sleep $sleepTimeSecs
        try {
            if($selectedSources.Count -gt 0){
                $runs = api get "protectionRuns?jobId=$($job.id)&startTimeUsecs=$startUsecs&numRuns=1000&sourceId=$($selectedSources[0])"
            }else{
                $runs = api get "protectionRuns?jobId=$($job.id)&startTimeUsecs=$startUsecs&numRuns=1000"
            }
            if($runs){
                $runs = $runs | Where-Object {$_.backupRun.jobRunId -eq $newRunId}
                if($runs -and $runs[0].PSObject.Properties['backupRun']){
                    if($runs[0].backupRun.PSObject.Properties['status']){
                        $lastStatus = $runs[0].backupRun.status
                        $statusRetryCount = 0
                    }
                }else{
                    $statusRetryCount += 1
                }
                try{
                    if($progress){
                        $progressTotal = 0
                        $progressPaths = $runs[0].backupRun.sourceBackupStatus.progressMonitorTaskPath
                        $sourceCount = $runs[0].backupRun.sourceBackupStatus.Count
                        foreach($progressPath in $progressPaths){
                            $progressMonitor = api get "/progressMonitors?taskPathVec=$progressPath&includeFinishedTasks=true&excludeSubTasks=false"
                            $thisProgress = $progressMonitor.resultGroupVec[0].taskVec[0].progress.percentFinished
                            $progressTotal += $thisProgress
                        }
                        $percentComplete = $progressTotal / $sourceCount
                        $statusRetryCount = 0
                        if($percentComplete -ne $lastProgress){
                            "{0} percent complete" -f [math]::Round($percentComplete, 0)
                            $lastProgress = $percentComplete
                        }
                    }
                }catch{
                    $statusRetryCount += 1
                }
            }else{
                $statusRetryCount += 1
            }
        }catch{
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
    }
}

$statusMap = @('0', '1', '2', 'kCanceled', 'kSuccess', 'kFailed', 'kWarning')

if($wait -or $progress){
    if($runs[0].backupRun.status -in @('3', '4', '5', '6')){
        $runs[0].backupRun.status = $statusMap[$runs[0].backupRun.status]
    }
    output "Job finished with status: $($runs[0].backupRun.status.subString(1))"
    if($outputlog){
        "Backup ended $(usecsToDate $runs[0].backupRun.stats.endTimeUsecs)" | Out-File -FilePath $scriptlog -Append
    }
    if($runs[0].backupRun.status -eq 'kSuccess'){
        exit 0
    }else{
        if($runs[0].backupRun.status -eq 'kFailure'){
            output "Error: $($runs[0].backupRun.error)"
        }
        if($runs[0].backupRun.status -eq 'kWarning'){
            output "Warning: $($runs[0].backupRun.warnings)"
        }
        exit 1
    }
}

exit 0
