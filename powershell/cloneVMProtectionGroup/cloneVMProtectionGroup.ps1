# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$sourceCluster,
    [Parameter(Mandatory = $True)][string]$sourceUser,
    [Parameter()][switch]$useHelios,
    [Parameter()][string]$heliosURL = 'helios.cohesity.com',
    [Parameter()][string]$sourceDomain = 'local',
    [Parameter()][string]$sourcePassword = $null,
    [Parameter()][string]$targetCluster = $sourceCluster,
    [Parameter()][string]$targetUser = $sourceUser,
    [Parameter()][string]$targetDomain = $sourceDomain,
    [Parameter()][string]$targetPassword = $null,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][string]$prefix = '',
    [Parameter()][string]$suffix = '',
    [Parameter()][string]$newJobName,
    [Parameter()][string]$newPolicyName,
    [Parameter()][string]$newStorageDomainName,
    [Parameter()][switch]$pauseNewJob,
    [Parameter()][switch]$pauseOldJob,
    [Parameter()][switch]$clearObjects,
    [Parameter()][string]$vCenterName,
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmList = ''
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


$oldVmFolderPaths = @{}

function walkOldVMFolders($thisvCenterName, $node, $parent=$null, $fullPath=''){
    $nodeTypes = @('kDataCenter', 'kFolder')
    if($thisvCenterName -notin $oldVmFolderPaths.keys){
        $oldVmFolderPaths[$thisvCenterName] = @{}
    }
    if($node.protectionSource.vmWareProtectionSource.type -eq 'kFolder'){
        $fullPath = "{0}/{1}" -f $fullPath, $node.protectionSource.name
        $oldVmFolderPaths[$thisvCenterName]["$($node.protectionSource.id)"] = $fullPath
    }
    if($node.PSObject.Properties['nodes']){
        foreach($subnode in $node.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.type -in $nodeTypes}){
            walkOldVMFolders $thisvCenterName $subnode $node $fullPath
        }
    }
}


$newVmFolderPaths = @{}

function walkNewVMFolders($thisvCenterName, $node, $parent=$null, $fullPath=''){
    $nodeTypes = @('kDataCenter', 'kFolder')
    if($thisvCenterName -notin $newVmFolderPaths.keys){
        $newVmFolderPaths[$thisvCenterName] = @{}
    }
    if($node.protectionSource.vmWareProtectionSource.type -eq 'kFolder'){
        $fullPath = "{0}/{1}" -f $fullPath, $node.protectionSource.name
        $newVmFolderPaths[$thisvCenterName][$fullPath] = $node.protectionSource.id 
    }
    if($node -and $node.PSObject.Properties['nodes']){
        foreach($subnode in $node.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.type -in $nodeTypes}){
            walkNewVMFolders $thisvCenterName $subnode $node $fullPath
        }
    }
}


function getObjectId($objectName, $sources){
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


function getObjectById($objectId, $source){
    $global:_object = $null

    function get_nodes($obj){
        if($obj.protectionSource.id -eq $objectId){
            $global:_object = $obj
            break
        }     
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object){
                    get_nodes $node
                }
            }
        }
    }    
    if($null -eq $global:_object){
        get_nodes $source
    }
    return $global:_object
}


function getObjectByMoRef($moRef, $source){
    $global:_object_id = $null

    function get_nodes($obj){
        if($obj.protectionSource.vmWareProtectionSource.id.morItem -eq $moRef -or $obj.protectionSource.vmWareProtectionSource.id.uuid -eq $moRef){
            $global:_object_id = $obj.protectionSource.id
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
    
    if($null -eq $global:_object_id){
        get_nodes $source
    }

    return $global:_object_id
}


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


# gather list of vms to add to new job
$vmNames = @(gatherList -Param $vmName -FilePath $vmList -Name 'jobs' -Required $false)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if($useHelios){
    apiauth -vip $heliosURL -username $sourceUser -domain $sourceDomain -helios
    $thisCluster = heliosCluster $sourceCluster
    if(! $thisCluster){
        exit
    }
}else{
    apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -passwd $sourcePassword
}

if(! $AUTHORIZED -and ! $cohesity_api.authorized){
    Write-Host "Failed to connect to Cohesity cluster" -foregroundcolor Yellow
    exit
}

"`nGetting source job details..."
$job = (api get -v2 'data-protect/protection-groups?environments=kVMware&isActive=true').protectionGroups | Where-Object name -eq $jobName

if($job){
    if($job.Count -gt 1){
        Write-Host "There is more than one job with the same name, please rename one of them" -foregroundcolor Yellow
        exit
    }

    # determine new job name (force suffix -clone if nothing is specified)
    if(!$newJobName){
        $newJobName = $job.name
    }
    if($newJobName -eq $jobName -and $prefix -eq '' -and $suffix -eq '' -and $targetCluster -eq $sourceCluster){
        $suffix = 'Clone'
    }
    if($prefix){
        $newJobName = "$prefix-$newJobName"
    }
    if($suffix){
        $newJobName = "$newJobName-$suffix"
    }

    # pause old job
    if($pauseOldJob){
        "Pausing old job..."
        $pauseParams = @{
            "action" = "kPause";
            "ids" = @(
                $job.id
            )
        }
        $null = api post -v2 data-protect/protection-groups/states $pauseParams  
    }

    # pause new job
    if($pauseNewJob){
        $job.isPaused = $True
    }else{
        $job.isPaused = $false
    }

    $oldPolicy = (api get -v2 data-protect/policies).policies | Where-Object id -eq $job.policyId
    $oldStorageDomain = api get viewBoxes | Where-Object id -eq $job.storageDomainId
    $oldVCenter = api get "protectionSources?id=$($job.vmwareParams.sourceId)&environments=kVMware&includeVMFolders=true"
    
    walkOldVMFolders $oldVCenter.protectionSource.name $oldVCenter

    # connect to target cluster for sanity check
    if($targetCluster -ne $sourceCluster){
        "Connecting to target cluster..."
        if($useHelios){
            $thisCluster = heliosCluster $targetCluster
            if(! $thisCluster){
                exit
            }
        }else{
            apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -passwd $targetPassword -quiet
        }
    }

    # check for existing job
    $existingJob = (api get -v2 'data-protect/protection-groups').protectionGroups | Where-Object name -eq $newJobName
    if($existingJob){
        Write-Host "'$newJobName' already exists on target cluster" -ForegroundColor Yellow
        exit
    }

    "Confirming target job details..."
    # check for vCenter
    if(!$vCenterName){
        $newVCenterName = $job.vmwareParams.sourceName
    }else{
        $newVCenterName = $vCenterName
    }
    if($vCenterName -or $targetCluster -ne $sourceCluster){
        $newVCenter = api get "protectionSources/rootNodes?environments=kVMware" | Where-Object {$_.protectionSource.name -eq $newVCenterName}
        if(!$newVCenter){
            write-host "vCenter $newVCenterName is not registered" -ForegroundColor Yellow
            exit
        }else{
            $job.vmwareParams.sourceId = $newVCenter.protectionSource.id
        }
        $newVCenter = api get "protectionSources?id=$($newVCenter.protectionSource.id)&environments=kVMware&includeVMFolders=true" | Where-Object {$_.protectionSource.name -eq $newVCenterName}
    }else{
        $newVCenter = $oldVCenter
    }
    
    # check for storage domain
    if($newStorageDomainName){
        $oldStorageDomain.name = $newStorageDomainName
    }
    if($newStorageDomainName -or $targetCluster -ne $sourceCluster){
        $newStorageDomain = api get viewBoxes | Where-Object name -eq $oldStorageDomain.name
        if(!$newStorageDomain){
            Write-Host "Storage Domain $($oldStorageDomain.name) not found" -ForegroundColor Yellow
            exit
        }else{
            $job.storageDomainId = $newStorageDomain.id
        }
    }else{
        $newStorageDomain = $oldStorageDomain
    }

    # check for policy
    if($newPolicyName){
        $oldPolicy.name = $newPolicyName
    }
    if($newPolicyName -or $targetCluster -ne $sourceCluster){
        $newPolicy = (api get -v2 data-protect/policies).policies | Where-Object name -eq $oldPolicy.name
        if(!$newPolicy){
            Write-Host "Policy $($oldPolicy.name) not found" -ForegroundColor Yellow
            exit
        }else{
            $job.policyId = $newPolicy.id
        }
    }else{
        $newPolicy = $oldPolicy
    }

    walkNewVMFolders $newVCenterName $newVCenter

    # same vCenter, different cluster, keep and remap the objects
    if($targetCluster -ne $sourceCluster -and !$vCenterName -and !$clearObjects){

        # refresh vcenter if on a different cluster
        write-host "refreshing $($newVCenter.protectionSource.name)..."
        $result = api post protectionSources/refresh/$($newVCenter.protectionSource.id)
        $result = waitForRefresh($newVCenter.protectionSource.id)

        # include objects
        foreach($vm in $job.vmwareParams.objects){
            $oldObject = getObjectById $vm.id $oldVCenter
            $newObjectId = getObjectByMoRef $oldObject.protectionSource.vmWareProtectionSource.id.morItem $newVCenter
            $vm.id = $newObjectId
            if($newObjectId -eq $null){
                Write-Host "`nSelected objects are missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
                exit
            }
        }

        # exclude objects
        if($job.vmwareParams.PSObject.Properties['excludeObjectIds']){
            $newExcludeIds = @()
            foreach($excludeId in $job.vmwareParams.excludeObjectIds){
                $oldObject = getObjectById $excludeId $oldVCenter
                $newObjectId = getObjectByMoRef $oldObject.protectionSource.vmWareProtectionSource.id.morItem $newVCenter
                $newExcludeIds = @($newExcludeIds + $newObjectId)
                if($newObjectId -eq $null){
                    Write-Host "`nSelected objects are missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
                    exit
                }
            }
            $job.vmwareParams.excludeObjectIds = $newExcludeIds
        }

        # include tags
        if($job.vmwareParams.PSObject.Properties['vmTagIds']){
            $newTagIds = @()
            foreach($tag in $job.vmwareParams.vmTagIds){
                $newTag = @()
                foreach($tagId in $tag){
                    $oldObject = getObjectById $tagId $oldVCenter
                    $newObjectId = getObjectByMoRef $oldObject.protectionSource.vmWareProtectionSource.id.uuid $newVCenter
                    $newTag = @($newTag + $newObjectId)
                    if($newObjectId -eq $null){
                        Write-Host "`nSelected objects are missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
                        exit
                    }
                }
                $newTagIds = @($newTagIds + ,$newTag)
            }
            $job.vmwareParams.vmTagIds = @($newTagIds)
        }

        # exclude tags
        if($job.vmwareParams.PSObject.Properties['excludeVmTagIds']){
            $newTagIds = @()
            foreach($tag in $job.vmwareParams.excludeVmTagIds){
                $newTag = @()
                foreach($tagId in $tag){
                    $oldObject = getObjectById $tagId $oldVCenter
                    $newObjectId = getObjectByMoRef $oldObject.protectionSource.vmWareProtectionSource.id.uuid $newVCenter
                    $newTag = @($newTag + $newObjectId)
                    if($newObjectId -eq $null){
                        Write-Host "`nSelected objects are missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
                        exit
                    }
                }
                $newTagIds = @($newTagIds + ,$newTag)
            }
            $job.vmwareParams.excludeVmTagIds = @($newTagIds)
        }
    }

    # if different vCenter, clear the objects and select new object(s)
    if($vCenterName){
        if($clearObjects -or $vmNames.Count -gt 0){
            # clear existing objects
            $job.vmwareParams.objects = @()
            delApiProperty -obj $job.vmwareParams -name excludeObjectIds
            delApiProperty -obj $job.vmwareParams -name vmTagIds
            delApiProperty -obj $job.vmwareParams -name excludeVmTagIds
            # add new VMs
            $registeredVMs = api get protectionSources/virtualMachines?vCenterId=$($job.vmwareParams.sourceId)
            foreach($vmToAdd in $vmNames){
                $vm = $registeredVMs | Where-Object {$_.name -ieq $vmToAdd}
                if(!$vm){
                    Write-Host "VM $vmToAdd not found!" -ForegroundColor Yellow
                }else{
                    $newVMobject = @{
                        'excludeDisks' = $null;
                        'id' = $vm.id;
                        'name' = $vm.name;
                        'isAutoprotected' = $false
                    }
                    $job.vmwareParams.objects = @(@($job.vmwareParams.objects | Where-Object {$_.id -ne $vm.id}) + $newVMobject)
                }
            }
            # bail if no VMs were added
            if($job.vmwareParams.objects.Count -eq 0){
                Write-Host "At least one VM must be added to the new job" -foregroundcolor Yellow
                exit
            }
        }else{
            # remap VM ids to new vCenter
            foreach($vm in $job.vmwareParams.objects){
                if([string]$($vm.id) -in $oldVmFolderPaths[$oldVCenter.protectionSource.name].keys){
                    $newObjectId = $newVmFolderPaths[$newVCenter.protectionSource.name][$oldVmFolderPaths[$oldVCenter.protectionSource.name][[string]$($vm.id)]]
                }else{
                    $newObjectId = getObjectId $vm.name $newVCenter
                }
                $vm.id = $newObjectId
                if($newObjectId -eq $null){
                    Write-Host "`nSelected object $($vm.name) is missing on target vCenter" -foregroundcolor Yellow
                    exit
                }
            }
            # exclude objects
            if($job.vmwareParams.PSObject.Properties['excludeObjectIds']){
                $newExcludeIds = @()
                foreach($excludeId in $job.vmwareParams.excludeObjectIds){
                    if([string]$excludedId -in $oldVmFolderPaths[$oldVCenter.protectionSource.name].keys){
                        $newObjectId = $newVmFolderPaths[$oldVCenter.protectionSource.name][$newVmFolderPaths[$oldVCenter.protectionSource.name][[string]$($vm.id)]]
                    }else{
                        $oldObject = getObjectById $excludeId $oldVCenter
                        $newObjectId = getObjectId $oldObject.protectionSource.name $newVCenter
                    }
                    if($newObjectId -eq $null){
                        Write-Host "`n    Warning: selected exclude object $($oldObject.protectionSource.name) is missing" -foregroundcolor Yellow
                    }else{
                        $newExcludeIds = @($newExcludeIds + $newObjectId)
                    }
                }
                $job.vmwareParams.excludeObjectIds = $newExcludeIds
            }
            # include tags
            if($job.vmwareParams.PSObject.Properties['vmTagIds']){
                $newTagIds = @()
                foreach($tag in $job.vmwareParams.vmTagIds){
                    $newTag = @()
                    foreach($tagId in $tag){
                        $oldObject = getObjectById $tagId $oldVCenter
                        $newObjectId = getObjectId $oldObject.protectionSource.name $newVCenter
                        $newTag = @($newTag + $newObjectId)
                        if($newObjectId -eq $null){
                            Write-Host "`nSelected tag $($oldObject.protectionSource.name) is missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
                            exit
                        }
                    }
                    $newTagIds = @($newTagIds + ,$newTag)
                }
                $job.vmwareParams.vmTagIds = @($newTagIds)
            }
            # exclude tags
            if($job.vmwareParams.PSObject.Properties['excludeVmTagIds']){
                $newTagIds = @()
                foreach($tag in $job.vmwareParams.excludeVmTagIds){
                    $newTag = @()
                    foreach($tagId in $tag){
                        $oldObject = getObjectById $tagId $oldVCenter
                        $newObjectId = getObjectId $oldObject.protectionSource.name $newVCenter
                        $newTag = @($newTag + $newObjectId)
                        if($newObjectId -eq $null){
                            Write-Host "`nSelected tag $($oldObject.protectionSource.name) is missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
                            exit
                        }
                    }
                    $newTagIds = @($newTagIds + ,$newTag)
                }
                $job.vmwareParams.excludeVmTagIds = @($newTagIds)
            }
        }
    }

    # create new job
    $job.name = $newJobName
    "`nCreating job '$newJobName' on $targetCluster...`n"
    $newjob = api post -v2 data-protect/protection-groups $job
}else{
    Write-Host "VMware Job $jobName not found" -ForegroundColor Yellow
}
