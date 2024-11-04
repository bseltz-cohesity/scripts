# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$configFolder = './configExports',
    [Parameter(Mandatory = $True)][string]$policyName,
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain',
    [Parameter()][array]$jobNames
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

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

function getObjectId($objectName, $source){
    $global:_object_id = $null

    function get_nodes($obj){
        if($obj.protectionSource.awsProtectionSource.resourceId -eq $objectName){
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
    
    get_nodes $source
    return $global:_object_id
}

# get old jobs
$jobsPath = Join-Path -Path $configFolder -ChildPath 'awsJobs.json'
if(! (Test-Path -PathType Leaf -Path $jobsPath)){
    Write-Host "jobs file not found" -ForegroundColor Yellow
    exit
}
$oldJobs = (get-content $jobsPath | ConvertFrom-Json) | Where-Object {$_.environment -eq 'kAWS' -and $_.isDeleted -ne $True -and $_.isActive -ne $false}

if($jobNames.Count -gt 0){
    $oldJobs = $oldJobs | Where-Object {$_.name -in $jobNames}
}

if($oldJobs.Count -lt 1){
    Write-Host "No jobs found for import" -ForegroundColor Yellow
    exit 1
}

# get old sources
$sourcesPath = Join-Path -Path $configFolder -ChildPath 'awsSources.json'
if(! (Test-Path -PathType Leaf -Path $sourcesPath)){
    Write-Host "sources file not found" -ForegroundColor Yellow
    exit
}
$oldSources = get-content $sourcesPath | ConvertFrom-Json

# get current jobs and sources 
$jobs = api get -v2 data-protect/protection-groups
$sources = api get protectionSources?environments=kAWS
$policies = api get -v2 data-protect/policies

$policy = $policies.policies | Where-Object name -eq $policyName
if(! $policy){
    Write-Host "Policy $policyName not found!" -ForegroundColor Yellow
    exit 1
}

$viewBoxes = api get viewBoxes
$sd = $viewBoxes | Where-Object name -eq $storageDomain
if(! $sd){
    Write-Host "Storage Domain $storageDomain not found!" -ForegroundColor Yellow
    exit 1
}

foreach($oldJob in $oldJobs){
    
    $oldParentSource = $oldSources | Where-Object {$_.protectionSource.id -eq $oldJob.awsParams.snapshotManagerProtectionTypeParams.sourceId}
    $newParentSource = $sources | Where-Object {$_.protectionSource.name -eq $oldParentSource.protectionSource.name}
    $jobName = $oldJob.name
    $newJob = $jobs.protectionGroups | Where-Object {$_.name -eq $jobName}

    if(! $newJob){
        write-host "Importing Job $jobName" -ForegroundColor Green
        $oldJob | delApiProperty -name id
        $oldJob.storageDomainId = $sd.id
        $oldJob.policyId = $policy.id
        $oldJob.awsParams.snapshotManagerProtectionTypeParams.sourceId = $newParentSource.protectionSource.id
        $newObjects = @()
        foreach($object in $oldJob.awsParams.snapshotManagerProtectionTypeParams.objects){
            $newObject = $object
            $oldSource = getObjectById $object.id $oldParentSource
            $newSourceId = getObjectId $oldSource.protectionSource.awsProtectionSource.resourceId $newParentSource
            $newObject.id = $newSourceId
            $newObjects = @($newObjects + $newObject)
        }
        $oldJob.awsParams.snapshotManagerProtectionTypeParams.objects = $newObjects
        $newJob = api post -v2 data-protect/protection-groups $oldJob
    }else{
        write-host "Job $jobName already exists" -ForegroundColor Blue
    }
}
