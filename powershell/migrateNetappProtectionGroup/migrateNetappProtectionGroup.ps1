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
    [Parameter()][switch]$deleteOldJob,
    [Parameter()][switch]$deleteOldJobAndExit,
    [Parameter()][switch]$deleteOldSnapshots,
    [Parameter()][switch]$deleteReplica,
    [Parameter()][switch]$renameOldJob
)


function waitForRefresh($objectId){
    $authStatus = ""
    while($authStatus -ne 'kFinished'){
        $rootFinished = $false
        $appsFinished = $false
        Start-Sleep 2
        $rootNode = (api get "protectionSources/registrationInfo?ids=$objectId").rootNodes | Where-Object {$_.rootNode.id -eq $objectId}
        $authStatus = $rootNode.registrationInfo.authenticationStatus
    }
    return $rootNode.rootNode.id
}


function getObjectById($objectId, $source){
    $global:_object = $null

    function get_nodes($obj){
        if($obj.protectionSource.id -eq $objectId){
            $global:_object = $obj
            return $obj
        }     
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object){
                    get_nodes $node
                }else{
                    break
                }
            }
        }
    }    
    if($null -eq $global:_object){
        get_nodes $source
    }
    if($global:_object -eq $null){
        return $null
    }
}


function getObjectByName($oldObject, $source){
    $global:_object = $null

    function get_nodes($thisObj){
        if($oldObject.protectionSource.netappProtectionSource.type -eq 'kCluster' -and 
            $thisObj.protectionSource.name -eq $oldObject.protectionSource.name){
            $global:_object = $thisObj
            return $thisObj
            break
        }
        if($oldObject.protectionSource.netappProtectionSource.type -eq 'kVserver' -and
            $thisObj.protectionSource.name -eq $oldObject.protectionSource.name){
            $global:_object = $thisObj
            return $thisObj
            break
        }
        if($oldObject.protectionSource.netappProtectionSource.type -eq 'kVolume' -and
            $thisObj.protectionSource.name -eq $oldObject.protectionSource.name -and
            $thisObj.protectionSource.netappProtectionSource.volumeInfo.name -eq $oldObject.protectionSource.netappProtectionSource.volumeInfo.name){
            $global:_object = $thisObj
            return $thisObj
            break
        }
        if($thisObj.PSObject.Properties['nodes']){
            foreach($node in $thisObj.nodes){
                if($null -eq $global:_object){
                    get_nodes $node
                }else{
                    break
                }
            }
        }
    }    

    get_nodes $source
    if($global:_object -eq $null){
        return $null
    }
}


# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

"`nConnecting to source cluster..."
apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -passwd $sourcePassword -tenant $tenant -quiet

if($prefix){
    $newJobName = "$prefix-$newJobName"
}

if($suffix){
    $newJobName = "$newJobName-$suffix"
}

$job = (api get -v2 'data-protect/protection-groups?environments=kNetapp&isActive=true').protectionGroups | Where-Object name -eq $jobName

if($job){

    $oldPolicy = (api get -v2 data-protect/policies).policies | Where-Object id -eq $job.policyId
    $oldStorageDomain = api get viewBoxes | Where-Object id -eq $job.storageDomainId

    # connect to target cluster for sanity check
    if(!$deleteOldJobAndExit){
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

        # check for netapp source
        $newNetapp = api get "protectionSources?environments=kNetapp" | Where-Object {$_.protectionSource.name -eq $job.netappParams.sourceName}
        if(!$newNetapp){
            Write-Host "Netapp $($job.netappParams.sourceName) is not registered" -ForegroundColor Yellow
            exit
        }

        # refresh new Netapp
        Write-Host "refreshing $($newNetapp.protectionSource.name)..."
        $result = api post protectionSources/refresh/$($newNetapp.protectionSource.id)
        $result = waitForRefresh($newNetapp.protectionSource.id)

        # check for storage domain
        if($newStorageDomainName){
            $oldStorageDomain.name = $newStorageDomainName
        }
        $newStorageDomain = api get viewBoxes | Where-Object name -eq $oldStorageDomain.name
        if(!$newStorageDomain){
            Write-Host "Storage Domain $($oldStorageDomain.name) not found" -ForegroundColor Yellow
            exit
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
    if(!$deleteOldJobAndExit){
        "    Migrating ""$jobName"" from $sourceCluster to $targetCluster...`n"
        $oldNetapp = api get "protectionSources?id=$($job.netappParams.sourceId)&environments=kNetapp"
    }

    # clean up source cluster
    if($deleteOldJob -or $deleteOldJobAndExit){
        if($deleteOldJobAndExit){
            ""
        }
        "    Deleting old protection group..."
        if($deleteOldSnapshots){
            $delete = 'true'
        }else{
            $delete = 'false'
        }
        $null = api delete -v2 "data-protect/protection-groups/$($job.id)?deleteSnapshots=$delete"
        if($deleteOldJobAndExit){
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

        # rename job
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

    $job.storageDomainId = $newStorageDomain.id
    $job.policyId = $newPolicy.id
    $job.netappParams.sourceId = $newNetapp.protectionSource.id

    # pause new job
    if($pauseNewJob){
        $job.isPaused = $True
    }else{
        $job.isPaused = $false
    }

    # include objects
    foreach($obj in $job.netappParams.objects){
        $oldObject = getObjectById $obj.id $oldNetapp
        $newObject = getObjectByName $oldObject $newNetapp
        $obj.id = [int64]$($newObject.protectionSource.id)
        if($newObject -eq $null){
            Write-Host "`nSelected objects are missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
            exit
        }
    }

    # exclude objects
    if($job.netappParams.PSObject.Properties['excludeObjectIds']){
        $newExcludeIds = @()
        foreach($excludeId in $job.netappParams.excludeObjectIds){
            $oldObject = getObjectById $excludeId $oldNetapp
            $newObject = getObjectByName $oldObject $newNetapp
            $newExcludeIds = @($newExcludeIds + [int64]$($newObject.protectionSource.id))
            if($newObject -eq $null){
                Write-Host "`nExcluded objects are missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
                exit
            }
        }
        $job.netappParams.excludeObjectIds = $newExcludeIds
    }

    # create new job
    $job.name = $newJobName
    "    Creating job ""$newJobName"" on $targetCluster..."
    $newjob = api post -v2 data-protect/protection-groups $job
    "`nMigration Complete`n"
}else{
    Write-Host "VMware Job $jobName not found" -ForegroundColor Yellow
}
