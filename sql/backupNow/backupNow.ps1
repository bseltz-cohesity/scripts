# version 2022.05.25
# usage: ./backupNow.ps1 -vip mycluster -vip2 mycluster2 -username myusername -domain mydomain.net -jobName 'My Job' -keepLocalFor 5 -archiveTo 'My Target' -keepArchiveFor 5 -replicateTo mycluster2 -keepReplicaFor 5 -enable

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$vip2,                 # alternate cluster to connect to
    [Parameter()][string]$username = 'helios',  # username (local or AD)
    [Parameter()][string]$domain = 'local',     # local or AD domain
    [Parameter()][string]$tenant,         # tenant org name
    [Parameter()][string]$password,       # optional password
    [Parameter()][switch]$useApiKey,      # use API key for authentication
    [Parameter()][string]$clusterName,    # helios cluster to access 
    [Parameter(Mandatory = $True)][string]$jobName,  # job to run
    [Parameter()][switch]$usePolicy,      # deprecated (does nothibng)
    [Parameter()][switch]$localOnly,      # perform local backup only
    [Parameter()][switch]$noReplica,      # skip replication
    [Parameter()][switch]$noArchive,      # skip archival
    [Parameter()][string]$jobName2,       # alternate jobName to run
    [Parameter()][int]$keepLocalFor,      # keep local snapshot for x days
    [Parameter()][string]$replicateTo,    # optional - remote cluster to replicate to
    [Parameter()][int]$keepReplicaFor,    # keep replica for x days
    [Parameter()][string]$archiveTo,      # optional - target to archive to
    [Parameter()][int]$keepArchiveFor,    # keep archive for x days
    [Parameter()][switch]$enable,         # enable a disabled job, run it, then disable when done
    [Parameter()][ValidateSet('kRegular','kFull','kLog','kSystem','Regular','Full','Log','System')][string]$backupType = 'kRegular',
    [Parameter()][array]$objects,         # list of objects to include in run
    [Parameter()][switch]$progress,       # display progress percent
    [Parameter()][switch]$wait,           # wait for completion and report end status
    [Parameter()][switch]$helios,         # use helios on-prem
    [Parameter()][string]$logfile,        # name of log file
    [Parameter()][switch]$outputlog,      # enable logging
    [Parameter()][string]$metaDataFile,   # backup file list
    [Parameter()][switch]$abortIfRunning,  # exit if job is already running
    [Parameter()][int64]$waitMinutesIfRunning = 60,
    [Parameter()][int64]$cancelPreviousRunMinutes = 0,
    [Parameter()][int64]$statusRetries = 10
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if($outputlog){
    if($logfile){
        $scriptlog = $logfile
    }else{
        $scriptlog = $(Join-Path -Path $PSScriptRoot -ChildPath 'log-backupNow.log')
    }
    "$(Get-Date): backupNow started" | Out-File -FilePath $scriptlog
}

# log function
function output($msg, [switch]$warn){
    if($warn){
        Write-Host $msg -ForegroundColor Yellow
    }else{
        Write-Host $msg
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

if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -password $password -useApiKey -tenant $tenant
    if((! $AUTHORIZED -and ! $cohesity_api.authorized) -and $vip2){
        output "Failed to connect to $vip. Trying $vip2..." -warn
        apiauth -vip2 $vip -username $username -domain $domain -password $password -useApiKey
        $jobName = $jobName2
    }
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password -tenant $tenant
    if((! $AUTHORIZED -and ! $cohesity_api.authorized) -and $vip2){
        output "Failed to connect to $vip. Trying $vip2..." -warn
        $jobName = $jobName2
    }
}

if(! $AUTHORIZED -and ! $cohesity_api.authorized){
    output "Failed to connect to Cohesity cluster" -warn
    exit 1
}

if($vip -eq 'helios.cohesity.com'){
    if($clusterName){
        heliosCluster $clusterName
    }else{
        output "Please provide -clusterName when connecting through helios" -warn
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
        exit 1
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
        exit 1
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
    exit 1
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
                                    exit 1
                                }
                            }else{
                                # Oracle
                                $dbSource = $serverSource.auxChildren | Where-Object {$_.entity.displayName -eq "$db"}
                                if($dbSource -and ( $null -eq $backupJobSourceParams -or $dbSource.entity.id -in $backupJobSourceParams.appEntityIdVec)){
                                    $runNowParameter.databaseIds = @($runNowParameter.databaseIds + $dbSource.entity.id)
                                }else{
                                    output "$object not protected by job $jobName" -warn
                                    exit 1
                                }
                            }
                        }else{
                            output "Job is Volume based. Can not selectively backup instances/databases" -warn
                            exit 1
                        }
                    }
                }else{
                    output "Server $server not protected by job $jobName" -warn
                    exit 1
                }
            }else{
                output "Server $server not found" -warn
                exit 1
            }
        }else{
            $objectId = getObjectId $object
            if($objectId){
                $sourceIds += $objectId
                $selectedSources = @($selectedSources + $objectId)
            }else{
                output "Object $object not found" -warn
                exit 1
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
            Write-Host "-keepReplicaFor is required" -ForegroundColor Yellow
            exit 1
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
            exit 1
        }
    }
}

# add archival target and retention
if((! $localOnly) -and (! $noArchive)){
    if($archiveTo){
        if(! $keepArchiveFor){
            Write-Host "-keepArchiveFor is required" -ForegroundColor Yellow
            exit 1
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
            exit 1
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

# enable job
if($enable -and $cluster.clusterSoftwareVersion -gt '6.5'){
    $lastRunTime = (api get "protectionRuns?jobId=$jobId&numRuns=1&excludeTasks=true").backupRun.stats.startTimeUsecs
    while($True -eq (api get protectionJobs/$jobID).isPaused){
        $null = api post protectionJobState/$jobID @{ 'pause'= $false }
        Start-Sleep 2
    }
}

# run job
$result = api post ('protectionJobs/run/' + $jobID) $jobdata
$reportWaiting = $True
$now = Get-Date
$waitUntil = $now.AddMinutes($waitMinutesIfRunning)
while($result -ne ""){
    if((Get-Date) -gt $waitUntil){
        output "Timed out waiting for existing run to finish" -warn
        exit 1
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
    Start-Sleep 15
    $result = api post ('protectionJobs/run/' + $jobID) $jobdata -quiet
}
output "Running $jobName..."

# wait for new job run to appear
while($newRunId -le $lastRunId){
    Start-Sleep 1
    if($selectedSources.Count -gt 0){
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&sourceId=$($selectedSources[0])"
    }else{
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&excludeTasks=true"
    }
    $newRunId = $runs[0].backupRun.jobRunId
}
output "New Job Run ID: $newRunId"

# wait for job run to finish
if($wait -or $enable -or $progress){
    $statusRetryCount = 0
    $lastProgress = -1
    $lastStatus = 'unknown'
    while ($lastStatus -notin $finishedStates){
        Start-Sleep 15
        try {
            if($selectedSources.Count -gt 0){
                $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&sourceId=$($selectedSources[0])"
            }else{
                $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10"
            }
            if($runs){
                $runs = $runs | Where-Object {$_.backupRun.jobRunId -eq $newRunId}
                if($runs -and $runs[0].PSObject.Properties['backupRun']){
                    if($runs[0].backupRun.PSObject.Properties['status']){
                        $lastStatus = $runs[0].backupRun.status
                        $statusRetryCount = 0
                    }
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
                        if($percentComplete -ne $lastProgress){
                            "{0} percent complete" -f [math]::Round($percentComplete, 0)
                            $lastProgress = $percentComplete
                        }
                    }
                }catch{
                    Start-Sleep 1
                }
            }else{
                $statusRetryCount += 1
            }
        }catch{
            $statusRetryCount += 1
            Start-Sleep 5
        }
        if($statusRetryCount -gt $statusRetries){
            Write-Host "Timed out waiting for status update" -foregroundcolor Yellow
            exit 1
        }
    }
}

# disable job
if($enable -and $cluster.clusterSoftwareVersion -gt '6.5'){
    while($True -ne (api get protectionJobs/$jobID).isPaused){
        if($lastRunTime -lt (api get "protectionRuns?jobId=$jobId&numRuns=1&excludeTasks=true").backupRun.stats.startTimeUsecs){
            $null = api post protectionJobState/$jobID @{ 'pause'= $true }
        }else{
            Start-Sleep 2
        }
    }
}

$statusMap = @('0', '1', '2', 'Canceled', 'Success', 'Failed', 'Warning')

if($wait -or $enable -or $progress){
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
