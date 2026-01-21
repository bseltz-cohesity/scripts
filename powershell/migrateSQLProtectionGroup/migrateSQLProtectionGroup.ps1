# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$sourceCluster,
    [Parameter(Mandatory = $True)][string]$sourceUser,
    [Parameter()][string]$sourceDomain = 'local',
    [Parameter()][string]$sourcePassword = $null,
    [Parameter(Mandatory = $True)][string]$targetCluster,
    [Parameter()][string]$targetUser = $sourceUser,
    [Parameter()][string]$targetDomain = $sourceDomain,
    [Parameter()][string]$targetPassword = $null,
    [Parameter()][string]$tenant,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][string]$prefix = '',
    [Parameter()][string]$suffix = '',
    [Parameter()][string]$oldJobSuffix = $null,
    [Parameter()][string]$newJobName = $jobName,
    [Parameter()][string]$newPolicyName,
    [Parameter()][string]$newStorageDomainName,
    [Parameter()][switch]$pauseNewJob,
    [Parameter()][switch]$cleanupSourceObjects,
    [Parameter()][switch]$cleanupSourceObjectsAndExit,
    [Parameter()][switch]$deleteOldSnapshots,
    [Parameter()][switch]$deleteReplica,
    [Parameter()][switch]$renameOldJob,
    [Parameter()][switch]$targetNGCE,
    [Parameter()][switch]$exportServerList,
    [Parameter()][switch]$detachServers
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

function waitForRefresh($server){
    $authStatus = ""
    while($authStatus -ne 'kFinished'){
        Start-Sleep 2
        $rootNode = (api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kPhysical").rootNodes | Where-Object {$_.rootNode.name -eq $server}
        $authStatus = $rootNode.registrationInfo.authenticationStatus
    }
    return $rootNode.rootNode.id
}

function waitForAppRefresh($server){
    $authStatus = ""
    while($authStatus -ne 'kFinished'){
        Start-Sleep 2
        $rootNode = (api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kPhysical").rootNodes | Where-Object {$_.rootNode.name -eq $server}
        $appNode = $rootNode.registrationInfo.registeredAppsInfo | Where-Object {$_.environment -eq 'kSQL'}
        if($appNode){
            $authStatus = $appNode[0].authenticationStatus
        }
    }
    return $rootNode.rootNode.id
}

function Restart-Service([string]$CompName,[string]$ServiceName){
    $filter = 'Name=' + "'" + $ServiceName + "'" + ''
    $service = Get-WMIObject -ComputerName $CompName -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
    $service.StopService()
    while ($service.Started){
      Start-Sleep 2
      $service = Get-WMIObject -ComputerName $CompName -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
    }
    $service.StartService()
    Start-Sleep 2
}

function Detach-Agent([string]$server){
    Write-Host "    $server : Detaching Cohesity Agent from $sourceCluster"
    $null = Invoke-Command -Computername $server -ScriptBlock {
        $null = Remove-ItemProperty -Path "HKLM:\SOFTWARE\Cohesity\Agent" -Name 'cluster_vec_registry' -ErrorAction SilentlyContinue
        $null = Remove-ItemProperty -Path "HKLM:\SOFTWARE\Cohesity\Agent" -Name 'agent_id' -ErrorAction SilentlyContinue
        $null = Remove-ItemProperty -Path "HKLM:\SOFTWARE\Cohesity\Agent" -Name 'agent_incarnation_id' -ErrorAction SilentlyContinue
        $null = Remove-ItemProperty -Path "HKLM:\SOFTWARE\Cohesity\Agent" -Name 'agent_uid' -ErrorAction SilentlyContinue
        $null = Remove-ItemProperty -Path "HKLM:\SOFTWARE\Cohesity\Agent" -Name 'allow_multiple_cohesity_clusters' -ErrorAction SilentlyContinue
        $null = Remove-Item -Path "C:\ProgramData\Cohesity\Cert\server_cert" -ErrorAction SilentlyContinue
    }
    Write-Host "    Restarting Cohesity Agent"
    $null = Restart-Service $server 'CohesityAgent'
}

"`nConnecting to source cluster..."
apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -passwd $sourcePassword -tenant $tenant -quiet

if($prefix){
    $newJobName = "$prefix-$newJobName"
}

if($suffix){
    $newJobName = "$newJobName-$suffix"
}

$job = (api get -v2 'data-protect/protection-groups?environments=kSQL').protectionGroups | Where-Object name -eq $jobName

if($job){

    $oldPolicy = (api get -v2 data-protect/policies).policies | Where-Object id -eq $job.policyId
    $oldStorageDomain = $null
    if($job.storageDomainId -ne $null){
        $oldStorageDomain = api get viewBoxes | Where-Object id -eq $job.storageDomainId
    }
    $newStorageDomain = $null
    if(!$targetNGCE){
        # check for target storage domain
        if($newStorageDomainName){
            $oldStorageDomain.name = $newStorageDomainName
        }
        
        $newStorageDomain = $null
        if($oldStorageDomain -ne $null){
            $newStorageDomain = api get viewBoxes | Where-Object name -eq $oldStorageDomain.name
            if(!$newStorageDomain){
                Write-Host "Storage Domain $($oldStorageDomain.name) not found" -ForegroundColor Yellow
                exit
            }
        }
    }

    # connect to target cluster for sanity check
    if(!$cleanupSourceObjectsAndExit -and !$exportServerList){
        "Connecting to target cluster..."
        apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -passwd $targetPassword -tenant $tenant -quiet

        # check for existing job
        $existingJob = (api get -v2 'data-protect/protection-groups').protectionGroups | Where-Object name -eq $newJobName
        if($existingJob){
            if($existingJob.isActive -eq $false -and $deleteReplica){
                "    Deleting existing replica job..."
                $null = api delete -v2 data-protect/protection-groups/$($existingJob.id)
            }else{
                Write-Host "job '$newJobName' already exists on target cluster" -ForegroundColor Yellow
                exit
            }
        }

        # check for policy
        if($newPolicyName){
            $oldPolicy.name = $newPolicyName
        }
        $newPolicy = (api get -v2 data-protect/policies).policies | Where-Object name -eq $oldPolicy.name
        if(!$newPolicy){
            Write-Host "Policy $($oldPolicy.name) not found" -ForegroundColor Yellow
            exit
        }
        apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -passwd $sourcePassword -tenant $tenant -quiet
    }

    # gather old job details
    if(!$cleanupSourceObjectsAndExit){
        "Migrating '$jobName' from $sourceCluster to $targetCluster...`n"
    }
    $oldSources = api get protectionSources?environments=kSQL

    # identify SQL job type
    $jobType = $job.mssqlParams.protectionType
    if($jobType -eq 'kFile'){
        $objectList = $job.mssqlParams.fileProtectionTypeParams.objects
    }elseif($jobType -eq 'kVolume'){
        $objectList = $job.mssqlParams.volumeProtectionTypeParams.objects
    }elseif ($jobType -eq 'kNative'){
        $objectList = $job.mssqlParams.nativeProtectionTypeParams.objects        
    }

    # identify servers to migrate
    $serversToMigrate = @()
    $objectsToMigrate = @{}

    foreach($server in $oldSources.nodes){
        $serverName = $server.protectionSource.name
        $serverType = $server.protectionSource.environment
        if($server.protectionSource.id -in $objectList.id){
            if($serverType -ne 'kPhysical'){
                Write-Host "This script does not support SQL servers registered as VMs" -ForegroundColor Yellow
                exit
            }
            $objectsToMigrate[$server.protectionSource.id] = @{'name' = "$serverName"; 'type' = 'server'}
            $serversToMigrate = @($serversToMigrate + $serverName | Sort-Object -Unique)
        }
        foreach($instance in $server.applicationNodes){
            $instanceName = $instance.protectionSource.name
            if($instance.protectionSource.id -in $objectList.id){
                if($serverType -ne 'kPhysical'){
                    Write-Host "This script does not support SQL servers registered as VMs" -ForegroundColor Yellow
                    exit
                }
                $objectsToMigrate[$instance.protectionSource.id] = @{'name' = "$serverName/$instanceName"; 'type' = 'instance'}
                $serversToMigrate = @($serversToMigrate + $serverName | Sort-Object -Unique)
            }
            foreach($database in $instance.nodes){
                $databaseName = $database.protectionSource.name
                if($database.protectionSource.id -in $objectList.id){
                    if($serverType -ne 'kPhysical'){
                        Write-Host "This script does not support SQL servers registered as VMs" -ForegroundColor Yellow
                        exit
                    }
                    $objectsToMigrate[$database.protectionSource.id] = @{'name' = "$serverName/$databaseName"; 'type' = 'database'}
                    $serversToMigrate = @($serversToMigrate + $serverName | Sort-Object -Unique)
                }
            }
        }
    }

    # export or detach servers
    if($exportServerList){
        $serversToMigrate | Out-File -FilePath physicalServers.txt
        Write-Host "`nServer list exported to physicalServers.txt`n"
        exit
    }

    if($detachServers){
        foreach($server in $serversToMigrate){
            Detach-Agent $server
        }
    }

    # clean up source cluster
    if($cleanupSourceObjects -or $cleanupSourceObjectsAndExit){
        if($cleanupSourceObjectsAndExit){
            ""
        }
        "    Deleting old protection group..."
        if($deleteOldSnapshots){
            $delete = 'true'
        }else{
            $delete = 'false'
        }
        $null = api delete -v2 "data-protect/protection-groups/$($job.id)?deleteSnapshots=$delete"
        Start-Sleep 10
        $rootNodes=api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kPhysical"
        foreach($server in $serversToMigrate){
            "    Unregistering $server..."
            $rootNode = $rootNodes.rootNodes | Where-Object {$_.rootNode.name -eq $server}
            $null = api delete protectionSources/$($rootNode.rootNode.id)
        }
        if($cleanupSourceObjectsAndExit){
            "`nCleanup Complete`n"
            exit
        }
    }else{
        # pause old job
        "    Pausing old job..."
        $pauseParams = @{
            "action" = "kPause";
            "ids" = @(
                $job.id
            )
        }
        $null = api post -v2 data-protect/protection-groups/states $pauseParams

        # rename old job
        if($renameOldJob){
            if(!$oldJobSuffix){
                $oldJobSuffix = (Get-Date).ToString('yyyy-MM-dd')
            }
            $job.name = "$($job.name)-$oldJobSuffix"
            "    Renaming old job to ""$($job.name)"""
            $null = api put -v2 data-protect/protection-groups/$($job.id) $job
        }
    }

    # connect to target cluster
    apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -passwd $targetPassword -tenant $tenant -quiet

    # register servers
    foreach($server in $serversToMigrate){
        "    Registering $server on $targetCluster..."
        $newSource = @{
            'entity' = @{
                'type' = 6;
                'physicalEntity' = @{
                    'name' = $server;
                    'type' = 1;
                    'hostType' = 1
                }
            };
            'entityInfo' = @{
                'endpoint' = $server;
                'type' = 6;
                'hostType' = 1
            };
            'sourceSideDedupEnabled' = $true;
            'throttlingPolicy' = @{
                'isThrottlingEnabled' = $false
            };
            'forceRegister' = $False
        }
        $null = api post /backupsources $newSource
        $entityId = waitForRefresh $server

        $regSQL = @{"ownerEntity" = @{"id" = $entityId}; "appEnvVec" = @(3)}
        $null = api post /applicationSourceRegistration $regSQL
        "    Waiting for SQL source refresh..."
        $null = api post protectionSources/refresh/$entityId
        $entityId = waitForAppRefresh $server
    }

    # update object IDs
    $newSources = api get protectionSources?environments=kSQL
    $newObjectList = @()
    foreach($objectItem in $objectList){
        $newItem = $objectItem
        $oldInfo = $objectsToMigrate[$($objectItem.id)]
        foreach($server in $newSources.nodes){
            $serverName = $server.protectionSource.name
            if($oldInfo.type -eq 'server' -and $oldInfo.name -eq $serverName){
                $newItem.id = $server.protectionSource.id
            }
            foreach($instance in $server.applicationNodes){
                $instanceName = $instance.protectionSource.name
                if($oldInfo.type -eq 'instance' -and $oldInfo.name -eq "$serverName/$instanceName"){
                    $newItem.id = $instance.protectionSource.id
                }
                foreach($database in $instance.nodes){
                    $databaseName = $database.protectionSource.name
                    if($oldInfo.type -eq 'database' -and $oldInfo.name -eq "$serverName/$databaseName"){
                        $newItem.id = $database.protectionSource.id
                    }
                }
            }
        }
        $newObjectList = @($newObjectList + $newItem)
    }
    if($jobType -eq 'kFile'){
        $job.mssqlParams.fileProtectionTypeParams.objects = $newObjectList
    }elseif ($jobType -eq 'kVolume'){
        $job.mssqlParams.volumeProtectionTypeParams.objects = $newObjectList
    }elseif($jobType -eq 'kNative'){
        $job.mssqlParams.nativeProtectionTypeParams.objects  = $newObjectList
    }

    if($newStorageDomain -eq $null){
        $job.storageDomainId = $null
    }else{
        $job.storageDomainId = $newStorageDomain.id
    }
    $job.policyId = $newPolicy.id

    # pause new job
    if($pauseNewJob){
        $job.isPaused = $True
    }else{
        $job.isPaused = $false
    }

    # create new job
    $job.name = $newJobName
    "    Creating job '$newJobName' on $targetCluster..."
    $newjob = api post -v2 data-protect/protection-groups $job
    "`nMigration Complete`n"
}else{
    Write-Host "Job $jobName not found" -ForegroundColor Yellow
}
