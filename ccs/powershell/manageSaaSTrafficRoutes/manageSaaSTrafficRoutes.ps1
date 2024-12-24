
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$connectionName,
    [Parameter()][string]$groupName,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][string]$vcUsername,
    [Parameter()][string]$vcPassword,
    [Parameter()][string]$entityName,
    [Parameter()][switch]$unassign,
    [Parameter()][switch]$listEntities
)

. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to CCS ===========================================
Write-Host "Connecting to Cohesity Cloud..."
apiauth -username $username -passwd $password
# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
$userInfo = api get /mcm/userInfo
$tenantId = $userInfo.user.profiles[0].tenantId
# ===============================================================

# get SaaS Connections
$rigelGroups = api get -mcmv2 "rigelmgmt/rigel-groups?tenantId=$tenantId"
$rigelGroup = $rigelGroups.rigelGroups | Where-Object {$_.groupName -eq $connectionName}
if(! $rigelGroup){
    Write-Host "SaaS Connection $connectionName not found" -ForegroundColor Yellow
    exit
}
$rigelGroup = api get -mcmv2 "rigelmgmt/rigel-groups?tenantId=$tenantId&maxRecordLimit=1000&groupId=$($rigelGroup.groupId)&fetchConnectorGroups=true"
$rigelGroup = $rigelGroup.rigelGroups[0]
$regionId = $rigelGroup.regionId

# get vCenter source
$sources = api get -mcmv2 "data-protect/sources?regionIds=$regionId&environments=kVMware"
$source = $sources.sources | Where-Object {$_.name -eq $sourceName}
if(! $source){
    Write-Host "Source $sourceName not found" -ForegroundColor Yellow
    exit
}
$sourceInfo = $source.sourceInfoList | Where-Object {$_.registrationDetails.connectionId -eq $rigelGroup.groupId}
if(! $sourceInfo){
    Write-Host "Source $sourceName is not assigned to SaaS Connection $connectionName" -ForegroundColor Yellow
    exit
}
$registrationId = $sourceInfo.registrationId
$sourceRegistration = api get -mcmv2 "data-protect/sources/registrations/$registrationId"
$protectionSource = api get "protectionSources?useCachedData=false&includeVMFolders=true&id=$($sourceInfo.sourceId)&environment=kVMware&excludeTypes=kVirtualMachine,kTag" -region $regionId

# index the vCenter hierarchy
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
                      'canonical' = "$parent/$($source.protectionSource.name)";
                      'shortCanonical' = ("$parent/$($source.protectionSource.name)" -replace '/Datacenters/','/' -replace '/vm/','/' -replace '/host/','/' -replace "/$sourceName/",'')}
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

$script:vmHierarchy[$sourceName] = @()
indexChildren $sourceName $protectionSource @()
$script:vmHierarchy[$sourceName] = $script:vmHierarchy[$sourceName] | ConvertTo-Json -Depth 99 | ConvertFrom-Json

# list entities
if($listEntities){
    foreach ($entity in $script:vmHierarchy[$sourceName] | Sort-Object -Property shortCanonical){
        Write-Host "$($entity.shortCanonical) ($($entity.type))"
    }
    exit
}

$update = $false

# unassign an entity
if($entityName -and $unassign){
    $vmEntity = $script:vmHierarchy[$sourceName] | Where-Object {$_.shortCanonical -eq $entityName -or $_.name -eq $entityName}
    if(! $vmEntity){
        Write-Host "`nEntity $entityName not found`n" -ForegroundColor Yellow
        exit
    }
    if($vmEntity.Count -gt 1){
        Write-Host "`nMore than one entity found - please use canonical name:" -ForegroundColor Yellow
        Write-Host "    $($vmEntity.shortCanonical -join "`n    ")" -ForegroundColor Yellow
        exit
    }
    $entityId = $vmEntity.id
    if($entityId -in $sourceRegistration.connections.entityId){
        Write-Host "`nUnassigning $($vmEntity.shortCanonical)`n"
        $sourceRegistration.connections = @($sourceRegistration.connections | Where-Object {$_.entityId -ne $entityId})
        $update = $True
    }else{
        Write-Host "`n$($vmEntity.shortCanonical) not assigned`n"
        exit
    }
}

# assign an entity to a group
if($groupName -and $entityName -and ! $unassign){
    $group = $namedGroups | Where-Object {$_.connectorGroupName -eq $groupName}
    if(! $group){
        Write-Host "`nConnector group $groupName not found`n" -ForegroundColor Yellow
        exit
    }
    $vmEntity = $script:vmHierarchy[$sourceName] | Where-Object {$_.shortCanonical -eq $entityName -or $_.name -eq $entityName}
    if(! $vmEntity){
        Write-Host "`nEntity $entityName not found`n" -ForegroundColor Yellow
        exit
    }
    if($vmEntity.Count -gt 1){
        Write-Host "`nMore than one entity found - please use canonical name:" -ForegroundColor Yellow
        Write-Host "    $($vmEntity.shortCanonical -join "`n    ")" -ForegroundColor Yellow
        exit
    }
    $entityId = $vmEntity.id
    Write-Host "`nAssigning $($vmEntity.shortCanonical) to $groupName`n"
    $sourceRegistration.connections = @($sourceRegistration.connections | Where-Object {$_.entityId -ne $entityId})
    $sourceRegistration.connections = @($sourceRegistration.connections + @{
        "connectionId" = $rigelGroup.groupId;
        "entityId" = $entityId;
        "connectorGroupId" = $group.connectorGroupId
    })
    $update = $True
}

if($update -eq $True){
    if($vcUsername){
        $sourceRegistration.vmwareParams.vCenterParams.username = $vcUsername
    }
    if(! $vcPassword){
        $securePassword = Read-Host -Prompt "Enter password for $($sourceRegistration.vmwareParams.vCenterParams.username)" -AsSecureString
        $vcPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $securePassword ))
    }
    $sourceRegistration.vmwareParams.vCenterParams.password = $vcPassword
    $response = api put -mcmv2 "data-protect/sources/registrations/$registrationId" $sourceRegistration
}

# list traffic routes
$connectorGroups = $rigelGroup.connectorGroups
$namedGroups = $connectorGroups | Where-Object {$_.isUngroup -eq $false}
foreach($group in $namedGroups | Sort-Object -Property connectorGroupName){
    Write-Host "`n$($group.connectorGroupName)"
    $sourceConnections = $sourceRegistration.connections | Where-Object {$_.connectorGroupId -eq $group.connectorGroupId}
    foreach($sourceConnection in $sourceConnections){
        $vmEntity = $script:vmHierarchy[$sourceName] | Where-Object {$_.id -eq $sourceConnection.entityId}
        Write-Host "    $($vmEntity.shortCanonical) ($($vmEntity.type.Substring(1)))"
    }
}
Write-Host ""
