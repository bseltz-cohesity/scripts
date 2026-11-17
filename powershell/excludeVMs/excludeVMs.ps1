### usage: ./excludeVMs.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'vm backup' -vmName mongodb

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$vmName,  # name of VM to protect
    [Parameter()][string]$vmList = '',  # text file of vm names
    [Parameter()][string]$vmMatch,
    [Parameter()][string]$tag,
    [Parameter()][switch]$prefixMatch,
    [Parameter()][array]$jobName,
    [Parameter()][switch]$removeExclusion
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
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

$vmToExclude = @(gatherList -Param $jobName -FilePath $jobList -Name 'VMs' -Required $false)

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

### get the protectionJob
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kVMware"

# gather list of servers to add to job
$vmsToExclude = @()

if($vmsToExclude.Count -eq 0 -and ! $vmMatch -and ! $tag){
    Write-Host "No VMs to exclude" -ForegroundColor Yellow
    exit
}

if($prefixMatch){
    $vmMatch = "^$vmMatch"
}

$vmsExcluded = $false
$vmCache = @{}
$tagCache = @{}

foreach($job in $jobs.protectionGroups){
    if($job.name -in $jobName -or $jobName.Count -eq 0){
        if($vmCache["$($job.vmwareParams.sourceId)"]){
            $vms = $vmCache["$($job.vmwareParams.sourceId)"]
            $tags = $tagCache["$($job.vmwareParams.sourceId)"]
        }else{
            $vms = api get "protectionSources/virtualMachines?vCenterId=$($job.vmwareParams.sourceId)"
            $tags = api get "protectionSources?id=1&excludeTypes=kComputeResource,kClusterComputeResource,kResourcePool,kDatastore,kHostSystem,kVirtualMachine,kVirtualApp,kStandaloneHost,kStoragePod,kNetwork,kDistributedVirtualPortgroup"
            $vmCache["$($job.vmwareParams.sourceId)"] = $vms
            $tagCache["$($job.vmwareParams.sourceId)"] = $tags
        }
        if($tag){
            $tagId = getObjectId $tag $tags
            if(!$tagId){
                write-host "Tag $tag not found!" -ForegroundColor Yellow
                continue
            }
            $vmsExcluded = $True
            if($removeExclusion){
                Write-Host "Removing tag exclusion for $tag from $($job.name)"
                $job.vmwareParams.excludeVmTagIds = @($job.vmwareParams.excludeVmTagIds | Where-Object {! (@($_).Count -eq 1 -and $tagId -in @($_))})
                if(@($job.vmwareParams.excludeVmTagIds).Count -eq 0){
                    $job.vmwareParams.excludeVmTagIds = $null
                }
            }else{
                Write-Host "Excluding tag $tag from $($job.name)"
                if(! $job.vmwareParams.PSObject.Properties['excludeVmTagIds']){
                    $job.vmwareParams | Add-Member -MemberType NoteProperty -Name 'excludeVmTagIds' -Value @(,@($tagId))
                }else{
                    $update = $True
                    foreach($item in $job.vmwareParams.excludeVmTagIds){
                        foreach($subitem in $item){
                            if($subitem -eq $tagId -and $update -eq $True){
                                $update = $false
                                continue
                            }
                        }
                    }
                    if($update -eq $True){
                        $job.vmwareParams.excludeVmTagIds += ,@($tagId)
                    }
                }
            }
        }
        if($vmMatch){
            $matchVMs = $vms | Where-Object {$_.name -match $vmMatch}
            $vmsToExclude = @($vmsToExclude + $matchVMs.name | Sort-Object -Unique)
        }
        foreach($vmName in $vmsToExclude){
            ### get the VM
            $vm = $vms | Where-Object {$_.name -ieq $vmName}
            if(!$vm){
                Write-Host "VM $vmName not found!" -ForegroundColor Yellow
            }else{
                $vmsExcluded = $True
                if($removeExclusion){
                    Write-Host "Removing exclusion for $vmName from $($job.name)"
                    if($job.vmwareParams.PSObject.Properties['excludeObjectIds']){
                        $job.vmwareParams.excludeObjectIds = @($job.vmwareParams.excludeObjectIds | Where-Object {$_ -ne $vm.id})
                    }
                }else{
                    Write-Host "Excluding $vmName from $($job.name)"
                    if(!$job.vmwareParams.PSObject.Properties['excludeObjectIds']){
                        setApiProperty -object $job.vmwareParams -name 'excludeObjectIds' -value @($vm.id)
                    }else{
                        $job.vmwareParams.excludeObjectIds = @($job.vmwareParams.excludeObjectIds + $vm.id)
                    }
                }
            } 
        }
        ### update the job
        if($vmsExcluded){
            $result = api put -v2 "data-protect/protection-groups/$($job.id)" $job
        }
    }
}


