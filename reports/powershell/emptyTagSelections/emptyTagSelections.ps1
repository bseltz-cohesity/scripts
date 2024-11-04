# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "emptyTagSelections-$($cluster.name)-$dateString.csv"

# headings
"Job Name,Selected VMs,VM Tag Selectors" | Out-File -FilePath $outfileName

$sources = api get protectionSources?environments=kVMware

function getVMTags($source){
    $global:vmTags = @{}
    
    function get_nodes($obj){
        if($obj.protectionSource.vmwareProtectionSource.tagAttributes.id){
            $global:vmTags[$obj.protectionSource.id] = @($obj.protectionSource.vmwareProtectionSource.tagAttributes.id)
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
    return $global:vmTags
}

$tags = @()

foreach($vCenter in $sources){
    $vmTags = getVMTags($vCenter)
    foreach($datacenter in $vCenter.nodes){
        $tagCategories = $datacenter.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.type -eq 'kTagCategory' }
        foreach($tag in $tagCategories.nodes){
            if($tag.protectedSourcesSummary.leavesCount){
                $leafCount = $tag.protectedSourcesSummary.leavesCount
            }else{
                $leafCount = 0
            }
            $tags = @($tags + @{'id' = $tag.protectionSource.id; 'name' = $tag.protectionSource.name; 'leafCount' = $leafCount})
        }
    }
}

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kVMware&includeTenants=true"

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $vmTagIds = $job.vmwareParams.vmTagIds
    $objects = $job.vmwareParams.objects
    if($objects.Count -eq 0 -and $vmTagIds.Count -gt 0){
        $objectCount = 0
        $tagGroups = @() 
        foreach($tagGroup in $vmTagIds){
            $tagGroupNames = @()
            foreach($tagId in $tagGroup){
                $tag = $tags | Where-Object id -eq $tagId
                $tagGroupNames = @($tagGroupNames + $tag.name)
            }
            $tagGroups = @($tagGroups + "[$($tagGroupNames -join ' + ')]")
            foreach($vmId in $vmTags.keys){
                $thisVMhasThisTagGroup = $True
                foreach($tagId in $tagGroup){
                    if($tagId -notin $vmTags[$vmId]){
                        $thisVMhasThisTagGroup = $false
                    }
                    if($thisVMhasThisTagGroup -eq $True){
                        $objectCount += 1
                    }
                }
            }
        }
        if($objectCount -eq 0){
            "$($job.name)    $objectCount VMs Selected    Tags: $($tagGroups -join ', ')"
            """$($job.name)"",""$objectCount"",""$($tagGroups -join '; ')""" | Out-File -FilePath $outfileName -Append
        }
    }
}

"`nOutput saved to $outfilename`n"
