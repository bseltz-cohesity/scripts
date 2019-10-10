# usage: ./backupNow.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -keepLocalFor 5 -archiveTo 'My Target' -keepArchiveFor 5 -replicateTo mycluster2 -keepReplicaFor 5 -enable

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,  # job to run
    [Parameter(Mandatory = $True)][array]$vmNames
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

function getObjectId($objectName){
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

# find the jobID
$job = (api get protectionJobs | Where-Object name -ieq $jobName)
if($job){
    $jobID = $job.id
    $sources = api get "protectionSources?id=$($job.parentSourceId)"
}else{
    Write-Warning "Job $jobName not found!"
    exit 1
}

$jobUpdate = $false

foreach($object in $vmNames){
    $objectId = getObjectId $object
    if($objectId){
        if($objectId -notin $job.sourceIds){
            "adding $object to protection job"
            $job.sourceIds += $objectId
            $jobUpdate = $True
        }else{
            "$object already in protection job"
        }
    }else{
        write-host "Object $object not found" -ForegroundColor Yellow
    }
}

if($jobUpdate){
    $null = api put protectionJobs/$jobID $job
}


