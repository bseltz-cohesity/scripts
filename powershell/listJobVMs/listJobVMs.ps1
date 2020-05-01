# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName  # folder to store export files
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

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

    get_nodes $source
    return $global:_object
}

function getAllChildren($source, $excludeList){
    $global:_list = @()

    function get_nodes($obj){
        if($obj.protectionSource.id -notin $excludeList){
            if($obj.PSObject.Properties['nodes']){
                foreach($node in $obj.nodes){
                    get_nodes $node
                }
            }else{
                $global:_list += $obj
            }
        }
    }
    get_nodes $source
    return $global:_list
}

# get job that has autoprotected VM folder
$job = api get protectionJobs | Where-Object {$_.name -eq $jobName -and $_.environment -eq 'kVMware'}
if(! $job){
    Write-Host "Job $jobName not found or is not a VMware job" -ForegroundColor Yellow
    exit
}

# get vCenter source for that job (note includeVMFolders)
$vCenterSource = api get "protectionSources?environments=kVMware&includeVMFolders=true" | Where-Object {$_.protectionSource.id -eq $job.parentSourceId }

# get list of excludedSourceIds if any
$excludeList = $job.excludeSourceIds
if($null -eq $excludeList){
    $excludeList = @()
}

# build list of protected VMs
$protectedVMs = @()


foreach($sourceId in $job.sourceIds){
    # find the folder object
    $protectedSource = getObjectById $sourceId $vCenterSource
    # get the child VMs of the folder
    $childVMs = getAllChildren $protectedSource $excludeList
    # add those child VMs to the list 
    $protectedVMs += $childVMs
}

# display the names of the VMs
foreach($vm in $protectedVMs){
    write-host $vm.protectionSource.name
}