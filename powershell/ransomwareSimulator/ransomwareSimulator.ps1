# version 2022.03.17

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',  # username (local or AD)
    [Parameter()][string]$domain = 'local',     # local or AD domain
    [Parameter()][string]$password,       # optional password
    [Parameter()][switch]$mcm,            # connect to MCM
    [Parameter()][switch]$useApiKey,      # use API key for authentication
    [Parameter()][string]$tenant,         # tenant org name
    [Parameter()][string]$clusterName,    # helios cluster to access 
    [Parameter(Mandatory = $True)][string]$jobName,  # job to run
    [Parameter()][array]$objects,         # list of objects to include in run
    [Parameter()][string]$filePath = '.'
)

# check for required PowerShell Edition
if($Host.Version.Major -le 5 -and $Host.Version.Minor -lt 1){
    Write-Host "PowerShell version must be upgraded to 5.1 or higher to connect to Cohesity!" -ForegroundColor Yellow
    exit
}

if($PSVersionTable.PSEdition -ne 'Desktop'){
    Write-Host "This script will not run in PowerShell Core" -ForegroundColor Yellow
    exit
}

# file path
if($(Test-Path -Path $filePath) -eq $false){
    Write-Host "FilePath $filePath not found" -ForegroundColor Yellow
    exit
}
if($filePath -match '\\\\'){
    Write-Host "UNC paths are not supported. Please map a network drive and use drive letter path instead" -ForegroundColor Yellow
    exit
}
$filePath = (Resolve-Path -Path $filePath).Path
$simPath = Join-Path -Path $filePath -ChildPath "ransomwareSimulatorData"
if($(Test-Path -Path $simPath) -eq $false){
    $null = New-Item -Type Directory -Path $simPath
}
if($(Test-Path -Path $simPath) -eq $false){
    Write-Host "No write access to file path" -ForegroundColor Yellow
    exit
}

# get or create certificate for encryption
$cert = Get-ChildItem -Path cert:\CurrentUser\My | Where-Object Subject -eq "CN=CohesityRansomwareSimulator"
if(!$cert){
    $cert = New-SelfSignedCertificate -DnsName 'CohesityRansomwareSimulator' -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsage KeyAgreement, KeyEncipherment, DataEncipherment -Type DocumentEncryptionCert
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$scriptlog = $(Join-Path -Path $PSScriptRoot -ChildPath 'log-ransomwareSimulator.txt')
"$(Get-Date): backupNow started" | Out-File -FilePath $scriptlog

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

# log command line parameters
"command line parameters:" | Out-File $scriptlog -Append
$CommandName = $PSCmdlet.MyInvocation.InvocationName;
$ParameterList = (Get-Command -Name $CommandName).Parameters;
foreach ($Parameter in $ParameterList) {
    Get-Variable -Name $Parameter.Values.Name -ErrorAction SilentlyContinue | Where-Object name -ne 'password' | Out-File $scriptlog -Append
}

# authenticate
if($mcm){
    apiauth -vip $vip -username $username -domain $domain -helios -password $password
}else{
    if($useApiKey){
        apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password -tenant $tenant
    }else{
        apiauth -vip $vip -username $username -domain $domain -password $password -tenant $tenant
    }
}

if(! $AUTHORIZED -and ! $cohesity_api.authorized){
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
                        if($environment -eq 'kOracle' -or $job.environmentParameters.sqlParameters.backupType -in @('kSqlVSSFile', 'kSqlNative')){
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
                                if($dbSource -and ( $null -eq $backupJobSourceParams -or $dbSource.entity.id -in $backupJobSourceParams.appEntityIdVec)){
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

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning', '3', '4', '5', '6')

# set local retention
$copyRunTargets = @(
    @{
        "type" = "kLocal";
        "daysToKeep" = 7
    }
)

# Finalize RunProtectionJobParam object
$jobdata = @{
   "runType" = $backupType
   "copyRunTargets" = $copyRunTargets
}

# add sourceIds if specified
if($objects){
    if(($environment -eq 'kSQL' -and $job.environmentParameters.sqlParameters.backupType -in @('kSqlVSSFile', 'kSqlNative')) -or $environment -eq 'kOracle'){
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

$statusMap = @('0', '1', '2', 'Canceled', 'Success', 'Failed', 'Warning')

function runBackup(){
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

    # run job
    $result = api post ('protectionJobs/run/' + $jobID) $jobdata
    $reportWaiting = $True

    while($result -ne ""){
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
        Start-Sleep 5
        if($selectedSources.Count -gt 0){
            $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&sourceId=$($selectedSources[0])"
        }else{
            $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&excludeTasks=true"
        }
        $newRunId = $runs[0].backupRun.jobRunId
    }

    # wait for job run to finish
    while ($runs[0].backupRun.status -notin $finishedStates){
        Start-Sleep 15
        if($selectedSources.Count -gt 0){
            $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1&sourceId=$($selectedSources[0])"
        }else{
            $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10&excludeTasks=true"
        }
        $runs = $runs | Where-Object {$_.backupRun.jobRunId -eq $newRunId}
    }

    if($runs[0].backupRun.status -in @('3', '4', '5', '6')){
        $runs[0].backupRun.status = $statusMap[$runs[0].backupRun.status]
    }
}

$rnd = New-Object Random;
$x = 1

function createRandomFile($fileNum){
    $fileName = Join-Path -Path $simPath -ChildPath "simfile$($fileNum).txt"
    $out = new-object byte[] 1048576
    $rnd.NextBytes($out)
    [IO.File]::WriteAllBytes($fileName, $out)
}

1..14 | ForEach-Object{
    output "Creating sim files..."
    1..72 | ForEach-Object{
        createRandomFile $x
        $x += 1
    }
    runBackup
}

# encrypt all files
output "Encrypting sim files..."
$simFiles = Get-ChildItem -Path $simPath
foreach($simFile in $simFiles){
    Protect-CmsMessage -content (Get-Content -Path $simFile.FullName) -To $cert.Subject -OutFile $simFile.FullName
}
runBackup
output "Simulation completed"
