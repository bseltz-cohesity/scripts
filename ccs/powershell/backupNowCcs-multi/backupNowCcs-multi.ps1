# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter(Mandatory = $True)][string]$region,  # Ccs region
    [Parameter()][array]$objectName,
    [Parameter()][string]$objectList,
    [Parameter()][switch]$fullBackup,
    [Parameter()][switch]$debugmode
)

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

$objectNames = @(gatherList -Param $objectName -FilePath $objectList -Name 'objects' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -regionid $region

$nowUsecs = dateToUsecs
$tomorrowUsecs = $nowUsecs + 86400000000
$weekAgoUsecs = timeAgo 1 week

$selectedObjects = @()

foreach($objectName in $objectNames){
    $objectName = [string]$objectName
    $objects = api get -v2 "data-protect/search/objects?searchString=$objectName&includeTenants=true"
    $objects = $objects.objects | Where-Object name -eq $objectName
    if($objects.Count -eq 0){
        Write-Host "$objectName not found" -ForegroundColor Yellow
        continue
    }
    
    $protectedObjects = api get -v2 data-protect/search/protected-objects?objectIds=$($objects[0].objectProtectionInfos[0].objectId)
    $protectedObjects = $protectedObjects.objects
    if($protectedObjects.Count -eq 0){
        Write-Host "$objectName is not protected" -ForegroundColor Yellow
        continue
    }
    
    $object = api get -v2 data-protect/objects?ids=$($objects[0].objectProtectionInfos[0].objectId)
    $thisSelectedObject = @{
        "id" = $protectedObjects[0].id;
        "takeLocalSnapshotOnly" = $false
    }
    if($fullBackup){
        $thisSelectedObject['backupType'] = 'kFull'
    }
    $selectedObjects = @($selectedObjects + $thisSelectedObject)
    Write-Host "Backing up $objectName"
}

$runParams = @{
    "action" = "ProtectNow";
    "runNowParams" = @{
        "objects" = $selectedObjects
    }
}

# handle multiple protections
$policies = $object.objects[0].objectBackupConfiguration.policyConfig.policies
if($policies.Count -gt 1){
    $runParams['snapshotBackendTypes'] = @()
    foreach($protectionType in $policies.protectionType){
        if($object.objects[0].environment -eq 'kAWS'){
            if($protectionType -eq 'kNative'){
                $protectionType = 'kAWSNative'
            }
            if($protectionType -eq 'kSnapshotManager'){
                $protectionType = 'kAWSSnapshotManager'
            }
        }
        $runParams['snapshotBackendTypes'] = @($runParams['snapshotBackendTypes'] + $protectionType)
    }
}

$result = api post -v2 data-protect/protected-objects/actions $runParams

if($debugmode){
    $result | ConvertTo-Json -Depth 99
}
