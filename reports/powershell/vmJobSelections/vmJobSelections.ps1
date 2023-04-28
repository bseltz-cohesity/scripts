# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',   # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',           # username (local or AD)
    [Parameter()][string]$domain = 'local',              # local or AD domain
    [Parameter()][switch]$useApiKey,                     # use API key for authentication
    [Parameter()][string]$password,                      # optional password
    [Parameter()][switch]$noPrompt,                      # do not prompt for password
    [Parameter()][string]$tenant,                        # org to impersonate
    [Parameter()][switch]$mcm,                           # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,               # MFA code
    [Parameter()][switch]$emailMfaCode,                  # email MFA code
    [Parameter()][string]$clusterName = $null,           # helios cluster to access
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][switch]$showExclusions,
    [Parameter()][switch]$vmNamesOnly,
    [Parameter()][switch]$summary
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

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)

Write-Host "Getting protection groups..."
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kVMware"

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$cluster = api get cluster
$outFileName = join-path -Path $PSScriptRoot -ChildPath "vmSelections-$($cluster.name).tsv"
"Cluster`tProtection Group`tVM`tDisposition`tSelected By`tSelected Entity`tContainer Path" | Out-File -FilePath $outfileName

$script:vmHierarchy = @{}

function indexChildren($vCenterName, $source, $parents = @(), $parent = ''){
    if($source.protectionSource.vmWareProtectionSource.PSObject.Properties['tagAttributes']){
        $parents = @($parents + $source.protectionSource.vmWareProtectionSource.tagAttributes.id)
    }
    $thisNode = $script:vmHierarchy[$vCenterName] | Where-Object id -eq $source.protectionSource.id
    if(! $thisNode){
        $thisNode = @{'id' = $source.protectionSource.id; 
                      'name' = $source.protectionSource.name; 
                      'type' = $source.protectionSource.vmWareProtectionSource.type; 
                      'parents' = $parents;
                      'parent' = $parent;
                      'alreadyIndexed' = $false;
                      'selected by' = $null;
                      'selected entity' = $null;
                      'autoprotected' = $false;
                      'canonical' = $null}
        $script:vmHierarchy[$vCenterName] = @($script:vmHierarchy[$vCenterName] + $thisNode) 
    }
    $thisNode.parents = @($thisNode.parents + $parents | Sort-Object -Unique)
    if($source.PSObject.Properties['nodes']){
        if($thisNode.alreadyIndexed -eq $false){
            $thisNode.alreadyIndexed = $True
            $parents = @($thisNode.parents + $source.protectionSource.id | Sort-Object -Unique)
            foreach($node in $source.nodes){
                indexChildren $vCenterName $node $parents "$parent/$($source.protectionSource.name)"
            }
        }
    }
}

function getChildren($vCenterName, $protectedObjectId){
    $vms = $script:vmHierarchy[$vCenterName] | Where-Object {$_.type -eq 'kVirtualMachine' -and ($protectedObjectId -in $_.parents -or $protectedObjectId -eq $_.id)}
    return $vms
}

function getTaggedVMs($vCenterName, $tags){
    $matchVMs = @()
    $matchTags = @()
    foreach($tag in $tags){
        $thisTag = $script:vmHierarchy[$vCenterName] | Where-Object {$_.id -eq $tag}
        $matchTags = @($matchTags + $thisTag.name)
        $tagVMs = getChildren $vCenterName $tag
        if($matchVMs.Count -eq 0){
            $matchVMs = @($tagVMs)
        }else{
            foreach($matchVM in $matchVMs){
                $matchingVM = $tagVMs | Where-Object {$_.id -eq $matchVM.id}
                if(!$matchingVM){
                    $matchVMs = @($matchVMs | Where-Object {$_.id -ne $matchVM.id})
                }
            }
        }
    }
    foreach($matchVM in $matchVMs){
        $matchVM.'selected by' = "Tag"
        $matchVM.'selected entity' = "$($matchTags -join ', ')"
        $matchVM.canonical = '-'
    }
    return $matchVMs
}

$vCenters = api get "protectionSources?includeVMFolders=true"

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){

    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        $autoprotected = $false
        $vCenterId = $job.vmwareParams.sourceId
        $vCenter = $vCenters | Where-Object {$_.protectionSource.id -eq $vCenterId}
        $vCenterName = $vCenter.protectionSource.name
        if($vCenterName -notin $script:vmHierarchy.Keys){
            $script:vmHierarchy[$vCenterName] = @()
            indexChildren $vCenterName $vCenter @()
            $script:vmHierarchy[$vCenterName] = $script:vmHierarchy[$vCenterName] | ConvertTo-Json -Depth 99 | ConvertFrom-Json
        }
        $protectedIds = @($job.vmwareParams.objects.id)
        $selectedVMs = @()
        $excludedVMs = @()
        $inclusionBy = @()
        $exclusionBy = @()
        # explicit and folder selections
        foreach($protectedId in $protectedIds){
            $protectedEntity = $script:vmHierarchy[$vCenterName] | Where-Object {$_.id -eq $protectedId}
            if($protectedEntity){
                $inclusionBy = @($inclusionBy + $protectedEntity.type.subString(1) | Sort-Object -Unique)
            }      
            $vms = getChildren $vCenterName $protectedId
            foreach($vm in $vms){
                if($vm.id -eq $protectedId){
                    $vm.'selected by' = "Name"
                    $vm.'selected entity' = '-'
                    $vm.canonical = "$($vm.parent)"
                }else{
                    $autoprotected = $True
                    $folder = $script:vmHierarchy[$vCenterName] | Where-Object {$_.id -eq $protectedId}
                    $vm.'selected by' = $folder.type.subString(1)
                    $vm.'selected entity' = $folder.name
                    $vm.canonical = "$($folder.parent)/$($folder.name)"
                }
            }
            $selectedVMs = @($selectedVMs + $vms)
        }

        # tag selections
        foreach($tags in $job.vmwareParams.vmTagIds){
            $inclusionBy = @($inclusionBy + 'Tag' | Sort-Object -Unique)
            $autoprotected = $True
            $matchVMs = getTaggedVMs $vCenterName $tags
            $selectedVMs = @($selectedVMs + $matchVMs)
        }

        # explicit and folder exclusions
        foreach($exclusion in $job.vmwareParams.excludeObjectIds){
            $excludedEntity = $script:vmHierarchy[$vCenterName] | Where-Object {$_.id -eq $exclusion}
            if($excludedEntity){
                $exclusionBy = @($exclusionBy + $excludedEntity.type.subString(1) | Sort-Object -Unique)
            }
            $excludeVMs = getChildren $vCenterName $exclusion
            $excludedVMs = @($excludedVMs + $excludeVMs)
            foreach($excludeVM in $excludeVMs){
                $selectedVMs = @($selectedVMs | Where-Object {$_.id -ne $excludeVM.id})
                if($excludeVM.id -eq $exclusion){
                    $excludeVM.'selected by' = "Name"
                    $excludeVM.'selected entity' = '-'
                    $excludeVM.canonical = "$($excludeVM.parent)"
                }else{
                    $folder = $script:vmHierarchy[$vCenterName] | Where-Object {$_.id -eq $exclusion}
                    $excludeVM.'selected by' = $folder.type.subString(1)
                    $excludeVM.'selected entity' = $folder.name
                    $excludeVM.canonical = "$($folder.parent)/$($folder.name)"
                }
            }
        }

        # tag exclusions
        foreach($tags in $job.vmwareParams.excludeVmTagIds){
            $exclusionBy = @($exclusionBy + 'Tag' | Sort-Object -Unique)
            $matchVMs = getTaggedVMs $vCenterName $tags
            foreach($matchVM in $matchVMs){
                $selectedVMs = @($selectedVMs | Where-Object {$_.id -ne $matchVM.id})
                $excludedVMs = @($excludedVMs + $matchVM)
            }
        }

        # output
        if($vmNamesOnly){
            Write-Host ""
            $selectedVMs.name | Sort-Object
            Write-Host ""
        }else{
            "`n========================================`nProtection Group: $($job.name)"
            "Autoprotected: $autoprotected"
            "Inclusions by: $(@($inclusionBy | Sort-Object -Unique) -join ', ')"
            if($excludedVMs.Count -gt 0){
                "Exclusions by: $(@($exclusionBy | Sort-Object -Unique) -join ', ')"
                # "Exclusions by: $(@($excludedVMs.'selected by' | Sort-Object -Unique) -join ', ')"
            }
            "========================================`n"
            if(!$summary){
                "Inclusions:"
                $selectedVMs | Sort-Object -Property name | Select-Object -Property name, 'selected by', 'selected entity' | Format-Table
                foreach($selectedVM in $selectedVMs){
                    "$($cluster.name)`t$($job.name)`t$($selectedVM.name)`tIncluded`t$($selectedVM.'selected by')`t$($selectedVM.'selected entity')`t$($selectedVM.canonical)" | Out-File -FilePath $outfileName -Append
                }
                if($showExclusions){
                    if($excludedVMs.Count -gt 0){
                        "Exclusions:"
                        $excludedVMs | Sort-Object -Property name | Select-Object -Property name, 'selected by', 'selected entity' | Format-Table
                        foreach($excludedVM in $excludedVMs){
                            "$($cluster.name)`t$($job.name)`t$($excludedVM.name)`tExcluded`t$($excludedVM.'selected by')`t$($excludedVM.'selected entity')`t$($excludedVM.canonical)" | Out-File -FilePath $outfileName -Append
                        }
                    }
                }
            }
        }
    }
}

"Output saved to $outfileName`n"
