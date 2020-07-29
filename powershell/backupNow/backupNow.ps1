# version 2020.07.24
# usage: ./backupNow.ps1 -vip mycluster -vip2 mycluster2 -username myusername -domain mydomain.net -jobName 'My Job' -keepLocalFor 5 -archiveTo 'My Target' -keepArchiveFor 5 -replicateTo mycluster2 -keepReplicaFor 5 -enable

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$vip2,       # alternate cluster to connect to
    [Parameter()][string]$username = 'helios',  # username (local or AD)
    [Parameter()][string]$domain = 'local',     # local or AD domain
    [Parameter()][string]$password = $null,     # optional password
    [Parameter()][switch]$useApiKey,  # use API key for authentication
    [Parameter()][string]$clusterName = $null,  # helios cluster to access 
    [Parameter(Mandatory = $True)][string]$jobName,  # job to run
    [Parameter()][switch]$usePolicy, # honor basic policy elements
    [Parameter()][string]$jobName2,             # alternate jobName to run
    [Parameter()][int]$keepLocalFor = 5,        # keep local snapshot for x days
    [Parameter()][string]$replicateTo = $null,  # optional - remote cluster to replicate to
    [Parameter()][int]$keepReplicaFor = 5,      # keep replica for x days
    [Parameter()][string]$archiveTo = $null,    # optional - target to archive to
    [Parameter()][int]$keepArchiveFor = 5,      # keep archive for x days
    [Parameter()][switch]$enable,    # enable a disabled job, run it, then disable when done
    [Parameter()][ValidateSet('kRegular','kFull','kLog','kSystem')][string]$backupType = 'kRegular',
    [Parameter()][array]$objects,    # list of objects to include in run
    [Parameter()][switch]$progress,  # display progress percent
    [Parameter()][switch]$wait,      # wait for completion and report end status
    [Parameter()][switch]$helios,    # use helios on-prem
    [Parameter()][string]$logfile, # name of log file
    [Parameter()][switch]$outputlog  # enable logging
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
    apiauth -vip $vip -username $username -domain $domain -password $password -useApiKey
    if((! $AUTHORIZED) -and $vip2){
        output "Failed to connect to $vip. Trying $vip2..." -warn
        apiauth -vip2 $vip -username $username -domain $domain -password $password -useApiKey
        $jobName = $jobName2
    }
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
    if((! $AUTHORIZED) -and $vip2){
        output "Failed to connect to $vip. Trying $vip2..." -warn
        $jobName = $jobName2
    }
}

if(! $AUTHORIZED){
    output "Failed to connect to Cohesity cluster" -warn
    exit 1
}

if($USING_HELIOS){
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
                    }
                    if($instance -or $db){                  
                        if($environment -eq 'kOracle' -or $job.environmentParameters.sqlParameters.backupType -eq 'kSqlVSSFile'){
                            $runNowParameter = $runNowParameters | Where-Object {$_.sourceId -eq $serverObjectId}
                            if(! $runNowParameter.databaseIds){
                                $runNowParameter.databaseIds = @()
                            }
                            $protectedDbList = api get "protectionSources/protectedObjects?environment=$environment&id=$serverObjectId" | Where-Object {$jobName -in $_.protectionJobs.name}
                            if($environment -eq 'kSQL'){
                                $protectedDb = $protectedDbList | Where-Object {$_.protectionSource.name -eq "$instance/$db"}
                            }else{
                                $protectedDb = $protectedDbList | Where-Object {$_.protectionSource.name -eq $db}
                            }               
                            if($protectedDb){
                                $runNowParameter.databaseIds += $protectedDb[0].protectionSource.id
                            }else{
                                output "$object not protected by job $jobName" -warn
                                exit 1
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
            }else{
                output "Object $object not found" -warn
                exit 1
            }
        }
    }
}

# get last run id
$runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10"
if($runs){
    $newRunId = $lastRunId = $runs[0].backupRun.jobRunId
}else{
    $newRunId = $lastRunId = 0
}

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure')

# wait for existing job run to finish
if($runs){
    $alertWaiting = $True
    while ($runs[0].backupRun.status -notin $finishedStates){
        if($alertWaiting){
            output "waiting for existing job run to finish..."
            $alertWaiting = $false
        }
        sleep 5
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10"
    }    
}

# set local retention
$copyRunTargets = @(
    @{
        "type" = "kLocal";
        "daysToKeep" = $keepLocalFor
    }
)

# retrieve policy settings
if($usePolicy){
    $policy = api get "protectionPolicies/$policyId"
    $copyRunTargets[0].daysToKeep = $policy.daysToKeep
    if($policy.PSObject.Properties['snapshotReplicationCopyPolicies']){
        foreach($replica in $policy.snapshotReplicationCopyPolicies){
            $copyRunTargets = $copyRunTargets + @{
                "daysToKeep"        = $replica.daysToKeep;
                "replicationTarget" = $replica.target;
                "type"              = "kRemote"
            }
        }
    }
    if($policy.PSObject.Properties['snapshotArchivalCopyPolicies']){
        foreach($archive in $policy.snapshotArchivalCopyPolicies){
            $copyRunTargets = $copyRunTargets + @{
                "archivalTarget" = $archive.target;
                "daysToKeep"     = $archive.daysToKeep;
                "type"           = "kArchival"
            }
        }
    }
}else{
    # add replication target and retention
    if ($replicateTo) {
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

    # add archival target and retention
    if($archiveTo){
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

# Add sourceIds if specified
if($objects){
    if(($environment -eq 'kSQL' -and $job.environmentParameters.sqlParameters.backupType -eq 'kSqlVSSFile') -or $environment -eq 'kOracle'){
        $jobdata['runNowParameters'] = $runNowParameters
    }else{
        $jobdata['sourceIds'] = $sourceIds
    }
}

# enable job
if($enable){
    $lastRunTime = (api get "protectionRuns?jobId=$jobId&numRuns=1").backupRun.stats.startTimeUsecs
    while($True -eq (api get protectionJobs/$jobID).isPaused){
        $null = api post protectionJobState/$jobID @{ 'pause'= $false }
        sleep 2
    }
}

# run job
output "Running $jobName..."

$null = api post ('protectionJobs/run/' + $jobID) $jobdata

# wait for new job run to appear
$x = 0
while($newRunId -eq $lastRunId){
    sleep 2
    $x += 1
    if($x -ge 30){
        output "Timed out waiting for new run" -warn
        exit 1
    }
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10"
    $newRunId = $runs[0].backupRun.jobRunId
}

# wait for job run to finish
if($wait -or $enable){
    $lastProgress = -1
    while ($runs[0].backupRun.status -notin $finishedStates){
        sleep 5
        if($progress){
            $progressMonitor = api get "/progressMonitors?taskPathVec=backup_$($newRunId)_1&includeFinishedTasks=true&excludeSubTasks=false"
            $percentComplete = $progressMonitor.resultGroupVec[0].taskVec[0].progress.percentFinished
            if($percentComplete -gt $lastProgress){
                "{0} percent complete" -f [math]::Round($percentComplete, 0)
                $lastProgress = $percentComplete
            }
        }
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10"
    }
}

# disable job
if($enable){
    while($True -ne (api get protectionJobs/$jobID).isPaused){
        if($lastRunTime -lt (api get "protectionRuns?jobId=$jobId&numRuns=1").backupRun.stats.startTimeUsecs){
            $null = api post protectionJobState/$jobID @{ 'pause'= $true }
        }else{
            sleep 2
        }
    }
}

if($wait -or $enable){
    output "Job finished with status: $($runs[0].backupRun.status)"

    if($runs[0].backupRun.status -eq 'kSuccess'){
        exit 0
    }else{
        exit 1
    }
}
