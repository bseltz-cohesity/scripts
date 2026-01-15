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
    [Parameter()][switch]$renameOldJob,
    [Parameter()][switch]$targetNGCE
)

function getObjectId($fqn, $source){
    $global:_object_id = $null

    function get_nodes($obj, $thisFQN){
        if($thisFQN -eq $fqn){
            $global:_object_id = $obj.protectionSource.id
            break
        }
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object_id){
                    get_nodes $node "$thisFQN/$($node.protectionSource.name)/"
                }
            }
        }
    }
    get_nodes $source
    return $global:_object_id
}

function getObjectById($objectId, $source){
    $fqn = '/'
    $global:_object = $null

    function get_nodes($obj, $fqn){
        if($obj.protectionSource.id -eq $objectId){
            setApiProperty -object $obj -name fqn -value $fqn
            $global:_object = $obj
            break
        }     
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object){
                    get_nodes $node "$fqn/$($node.protectionSource.name)/"
                }
            }
        }
    }    
    if($null -eq $global:_object){
        get_nodes $source
    }
    return $global:_object
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

$job = (api get -v2 'data-protect/protection-groups?environments=kAWS&isActive=true').protectionGroups | Where-Object {$_.name -eq $jobName} # -and $_.awsParams.protectionType -eq 'kSnapshotManager'}

if($job){

    $oldPolicy = (api get -v2 data-protect/policies).policies | Where-Object id -eq $job.policyId
    
    $oldStorageDomain = $null
    if($job.storageDomainId -ne $null){
        $oldStorageDomain = api get viewBoxes | Where-Object id -eq $job.storageDomainId
    }
    $newStorageDomain = $null
    if($job.awsParams.protectionType -ne 'kNative' -and !$targetNGCE){
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

    $oldStorageDomain = api get viewBoxes | Where-Object id -eq $job.storageDomainId
    
    # connect to target cluster for sanity check
    if(!$deleteOldJobAndExit){
        "Connecting to target cluster..."
        apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -passwd $targetPassword -tenant $tenant -quiet

        # check for existing job
        $existingJob = (api get -v2 'data-protect/protection-groups').protectionGroups | Where-Object name -eq $newJobName
        if($existingJob){
            if($existingJob.isActive -eq $false -and $deleteReplica){
                "Deleting existing replica job..."
                $null = api delete -v2 data-protect/protection-groups/$($existingJob.id)
            }else{
                Write-Host "job '$newJobName' already exists on target cluster" -ForegroundColor Yellow
                exit
            }
        }
        $paramsName = 'snapshotManagerProtectionTypeParams'
        if($job.awsParams.protectionType -eq 'kNative'){
            $paramsName = 'nativeProtectionTypeParams'
        } 
        # check for vCenter
        # $newAWSSource = api get "protectionSources?environments=kAWS" | Where-Object {$_.protectionSource.name -eq $job.awsParams.$paramsName.sourceName}
        $newAWSSourceReg = (api get protectionSources/registrationInfo?environments=kAWS).rootNodes | Where-Object { $_.rootNode.name -eq $job.awsParams.$paramsName.sourceName}
        $newAWSSourceReg | toJson
        if($newAWSSourceReg){
            $newAWSSourceId = $newAWSSourceReg.rootNode.id
            $newAWSSource = api get protectionSources?id=$newAWSSourceId
        }

        if(!$newAWSSource){
            write-host "AWS protection source $($job.awsParams.$paramsName.sourceName) is not registered" -ForegroundColor Yellow
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
        "Migrating ""$jobName"" from $sourceCluster to $targetCluster..."
        $oldAWSSource = api get "protectionSources?id=$($job.awsParams.$paramsName.sourceId)&environments=kAWS"
    }

    # clean up source cluster
    if($deleteOldJob -or $deleteOldJobAndExit){
        if($deleteOldJobAndExit){
            ""
        }
        "Deleting old protection group..."
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
        "Pausing old protection group..."
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
            "Renaming old protection group to ""$($job.name)"""
            $null = api put -v2 data-protect/protection-groups/$($job.id) $job
        }
    }

    # connect to target cluster
    apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -passwd $targetPassword -tenant $tenant -quiet

    $job.storageDomainId = $newStorageDomain.id
    $job.policyId = $newPolicy.id
    if($newStorageDomain -eq $null){
        $job.storageDomainId = $null
    }else{
        $job.storageDomainId = $newStorageDomain.id
    }
    $job.awsParams.$paramsName.sourceId = $newAWSSource.protectionSource.id

    # pause new job
    if($pauseNewJob){
        $job.isPaused = $True
    }else{
        $job.isPaused = $false
    }

    # include objects
    foreach($vm in $job.awsParams.$paramsName.objects){
        $oldObject = getObjectById $vm.id $oldAWSSource
        # $oldObject | ConvertTo-Json -Depth 99
        $newObjectId = getObjectId $oldObject.fqn $newAWSSource
        $vm.id = $newObjectId
        if($newObjectId -eq $null){
            Write-Host "`nSelected objects are missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
            exit
        }
    }

    # exclude objects
    if($job.awsParams.$paramsName.PSObject.Properties['excludeObjectIds']){
        $newExcludeIds = @()
        foreach($excludeId in $jobawsParams.$paramsName.excludeObjectIds){
            $oldObject = getObjectById $excludeId $oldAWSSource
            $newObjectId = getObjectId $oldObject.fqn $newAWSSource
            $newExcludeIds = @($newExcludeIds + $newObjectId)
            if($newObjectId -eq $null){
                Write-Host "`nExcluded objects are missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
                exit
            }
        }
        $job.awsParams.$paramsName.excludeObjectIds = $newExcludeIds
    }

    # include tags
    if($job.awsParams.$paramsName.PSObject.Properties['vmTagIds']){
        $newTagIds = @()
        foreach($tag in $job.awsParams.$paramsName.vmTagIds){
            $newTag = @()
            foreach($tagId in $tag){
                $oldObject = getObjectById $tagId $oldAWSSource
                $newObjectId = getObjectId $oldObject.fqn $newAWSSource
                $newTag = @($newTag + $newObjectId)
                if($newObjectId -eq $null){
                    Write-Host "`nTag objects are missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
                    exit
                }
            }
            $newTagIds = @($newTagIds + ,$newTag)
        }
        $job.awsParams.$paramsName.vmTagIds = @($newTagIds)
    }

    # exclude tags
    if($job.awsParams.$paramsName.PSObject.Properties['excludeVmTagIds']){
        $newTagIds = @()
        foreach($tag in $job.awsParams.$paramsName.excludeVmTagIds){
            $newTag = @()
            foreach($tagId in $tag){
                $oldObject = getObjectById $tagId $oldAWSSource
                $newObjectId = getObjectId $oldObject.fqn $newAWSSource
                $newTag = @($newTag + $newObjectId)
                if($newObjectId -eq $null){
                    Write-Host "`nExcluded tag objects are missing, please edit and save selections in the old job before migrating" -foregroundcolor Yellow
                    exit
                }
            }
            $newTagIds = @($newTagIds + ,$newTag)
        }
        $job.awsParams.$paramsName.excludeVmTagIds = @($newTagIds)
    }

    # create new job
    $job.name = $newJobName
    "Creating job ""$newJobName"" on $targetCluster..."
    $newjob = api post -v2 data-protect/protection-groups $job
    "`nMigration Complete`n"
}else{
    Write-Host "AWS protection group $jobName not found" -ForegroundColor Yellow
}
