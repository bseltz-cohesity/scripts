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
    [Parameter()][switch]$renameOldJob
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

function waitForRefresh($mountPoint){
    $authStatus = ""
    while($authStatus -ne 'kFinished'){
        Start-Sleep 2
        $rootNode = (api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kGenericNas").rootNodes | Where-Object {$_.rootNode.name -eq $mountPoint}
        $authStatus = $rootNode.registrationInfo.authenticationStatus
    }
    return $rootNode.rootNode.id
}

"`nConnecting to source cluster..."
apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -passwd $sourcePassword -tenant $tenant -quiet

if($prefix){
    $newJobName = "$prefix-$newJobName"
}

if($suffix){
    $newJobName = "$newJobName-$suffix"
}

$job = (api get -v2 'data-protect/protection-groups?environments=kGenericNas').protectionGroups | Where-Object name -eq $jobName

if($job){

    # gather old job info
    $oldPolicy = (api get -v2 data-protect/policies).policies | Where-Object id -eq $job.policyId
    $oldStorageDomain = $null
    if($job.storageDomainId -ne $null){
        $oldStorageDomain = api get viewBoxes | Where-Object id -eq $job.storageDomainId
    }
   

    # connect to target cluster for sanity check
    if(!$cleanupSourceObjectsAndExit){
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

        # check for target policy
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

    # gather more old job details
    if(!$cleanupSourceObjectsAndExit){
        "Migrating '$jobName' from $sourceCluster to $targetCluster...`n"
    }
    $oldSources = api get protectionSources?environments=kGenericNas

    $objectList = $job.genericNasParams.objects
 
    # identify servers to migrate
    $mountPointsToMigrate = @()
    $objectsToMigrate = @{}

    foreach($mountPoint in $oldSources.nodes){
        $mountPointName = $mountPoint.protectionSource.name
        if($mountPoint.protectionSource.id -in $objectList.id){
            $objectsToMigrate[$mountPoint.protectionSource.id] = @{'name' = "$mountPointName"; 'type' = 'server'}
            $mountPointsToMigrate = @($mountPointsToMigrate + $mountPointName | Sort-Object -Unique)
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
        $rootNodes=api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kGenericNas"
        foreach($mountPoint in $mountPointsToMigrate){
            "    Unregistering $mountPoint..."
            $rootNode = $rootNodes.rootNodes | Where-Object {$_.rootNode.name -eq $mountPoint}
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

    # # register servers
    # foreach($mountPoint in $mountPointsToMigrate){
    #     "    Registering $mountPoint on $targetCluster..."
    #     $newSource = @{
    #         'entity' = @{
    #             'type' = 6;
    #             'physicalEntity' = @{
    #                 'name' = $mountPoint;
    #                 'type' = 1;
    #                 'hostType' = 1
    #             }
    #         };
    #         'entityInfo' = @{
    #             'endpoint' = $mountPoint;
    #             'type' = 6;
    #             'hostType' = 1
    #         };
    #         'sourceSideDedupEnabled' = $true;
    #         'throttlingPolicy' = @{
    #             'isThrottlingEnabled' = $false
    #         };
    #         'forceRegister' = $force
    #     }
    #     $null = api post /backupsources $newSource

    #     $entityId = waitForRefresh $mountPoint
    # }

    # update object IDs
    $newSources = api get protectionSources?environments=kGenericNas
    $newObjectList = @()
    foreach($objectItem in $objectList){
        $newItem = $objectItem
        $oldInfo = $objectsToMigrate[$($objectItem.id)]
        foreach($mountPoint in $newSources.nodes){
            $mountPointName = $mountPoint.protectionSource.name
            if($oldInfo.type -eq 'server' -and $oldInfo.name -eq $mountPointName){
                $newItem.id = $mountPoint.protectionSource.id
            }
        }
        $newObjectList = @($newObjectList + $newItem)
    }
    $job.genericNasParams.objects = $newObjectList

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
