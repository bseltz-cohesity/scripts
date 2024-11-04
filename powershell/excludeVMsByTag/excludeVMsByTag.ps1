### Usage: ./excludeVMsByTag.ps1 -vip mycluster -username myusername -domain mydomain.net -tag 'DoNotBackup' -vCenterName myvcenter.mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$jobName,
    [Parameter(Mandatory = $True)][string]$vCenterName,
    [Parameter()][string]$tag
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

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

$vCenter = api get protectionSources?environments=kVMware | Where-Object {$_.protectionSource.name -eq $vCenterName}
if(!$vCenter){
    Write-Host "vCenter $vCenter not found!" -ForegroundColor Yellow
    exit 1
}

$tagId = getObjectId $tag $vCenter
if(!$tagId){
    write-host "Tag $tag not found!" -ForegroundColor Yellow
    exit 1
}

$jobs = api get protectionJobs?environments=kVMware | Where-Object {
    $_.isActive -ne $False -and 
    $_.isDeleted -ne $True -and 
    $_.parentSourceId -eq $vCenter.protectionSource.id
} | Sort-Object -Property name

if($jobName){
    $jobs = $jobs | Where-Object name -eq $jobName
    if(!$jobs){
        Write-Host "$jobName not found" -ForegroundColor Yellow
        exit
    }
}

foreach($job in $jobs){
    $update = $True
    if(! $job.PSObject.Properties['excludeVmTagIds']){
        $job | Add-Member -MemberType NoteProperty -Name 'excludeVmTagIds' -Value @(,@($tagId))
    }else{
        foreach($item in $job.excludeVmTagIds){
            foreach($subitem in $item){
                if($subitem -eq $tagId -and $update -eq $True){
                    "$tag already excluded from $($job.name)"
                    $update = $false
                    continue
                }
            }
        }
        $job.excludeVmTagIds += ,@($tagId)
    }
    if($update){
        "Excluding $tag from $($job.name)"
        $null = api put "protectionJobs/$($job.id)" $job
    }
}
