### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$searchString,
    [Parameter()][string]$objectName = '',
    [Parameter()][string]$objectType = '',
    [Parameter()][string]$jobName = '',
    [Parameter()][switch]$extensionOnly,
    [Parameter()][int]$pageSize = 100000
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$rootNodes = api get protectionSources?rootNodes
$sources = api get protectionSources
$jobs = api get -v2 data-protect/protection-groups
$cluster = api get cluster

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


"""JobName"",""Environment"",""Object"",""Path""" | Out-File -FilePath foundFiles.csv

$myObject = @{
    "fileParams" = @{
        "searchString" = $searchString;
        "sourceEnvironments" = @(
            "kAcropolis";
            "kAWS";
            "kAzure";
            "kGCP";
            "kHyperV";
            "kKVM";
            "kVMware";
            "kPhysical";
            "kNetapp";
            "kIsilon";
            "kGenericNas";
            "kFlashBlade";
            "kGPFS";
            "kElastifile";
            "kPhysicalFiles";
            "kView"
        );
        "objectIds" = @()
    };
    "objectType" = "Files"
    "protectionGroupIds" = @();
    "count" = $pageSize
}

if($objectType){
    $myObject.fileParams.sourceEnvironments = @($objectType)
}
if($jobName){
    $job = $jobs.protectionGroups | Where-Object name -eq $jobName
    if(!$job){
        Write-Host "Job $jobName not found" -ForegroundColor Yellow
        exit 1
    }
    $myObject.protectionGroupIds = @($job.id)
}
if($objectName){
    $sourceId = getObjectId $objectName
    if(!$sourceId){
        Write-Host "Object $objectName not found" -ForegroundColor Yellow
        exit 1
    }
    $myObject.fileParams.objectIds = @($sourceId)
}

$results = api post -v2 data-protect/search/indexed-objects $myObject
$fileCount = 0

$output = $results.files | where-object type -eq 'File' | Sort-Object -Property {$_.protectionGroupName}, {$_.path}
if($extensionOnly -and $searchString){
    $output = $output | Where-Object {$_.path -match $searchString+'$'}
}
foreach($result in $output){
    $objectName = $result.sourceInfo.name
    $fileName = $result.path + '/' + $result.name
    $parentName = ''
    $parentId = $result.sourceInfo.sourceId
    $jobName = $result.protectionGroupName
    $jobId = $result.protectionGroupId
    $environment = $result.sourceInfo.environment
    write-host ("{0},{1}" -f $objectName, $fileName)
    """{0}"",""{1}"",""{2}"",""{3}""" -f $jobName, $environment, $objectName, $fileName | Out-File -FilePath foundFiles.csv -Append
    $fileCount += 1
}

"`n$fileCount indexed files found"

"`nsaving results to foundFiles.csv"
