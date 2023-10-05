### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][ValidateSet('mailbox','onedrive','sites','teams','publicfolders')][string]$objectType = 'mailbox'
)

$queryParam = ''
if($objectType -eq 'mailbox'){
    $objectString = 'Mailboxes'
    $nodeString = 'users'
    $objectKtype = 'kMailbox'
    $environment68 = 'kO365Exchange'
    $queryParam = '&hasValidMailbox=true'
}elseif($objectType -eq 'onedrive'){
    $objectString = 'OneDrives'
    $nodeString = 'users'
    $objectKtype = 'kOneDrive'
    $environment68 = 'kO365OneDrive'
    $queryParam = '&hasValidOnedrive=true'
}elseif($objectType -eq 'sites'){
    $objectString = 'Sites'
    $nodeString = 'Sites'
    $objectKtype = 'kSharePoint'
    $environment68 = 'kO365Sharepoint'
}elseif($objectType -eq 'teams'){
    $objectString = 'Teams'
    $nodeString = 'Teams'
    $objectKtype = 'kTeams'
    $environment68 = 'kO365Teams'
}elseif($objectType -eq 'publicfolders'){
    $objectString = 'PublicFolders'
    $nodeString = 'PublicFolders'
    $objectKtype = 'kPublicFolders'
    $environment68 = 'kO365PublicFolders'
}else{
    Write-Host "Invalid objectType" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm

### select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

$outfileName = "unprotected-o365-$($objectType).csv"
# headings
"Name,SMTP Address,WebURL,UUID" | Out-File -FilePath $outfileName -Encoding utf8


Write-Host "`nDiscovering $objectString..."

$cluster = api get cluster
if($cluster.clusterSoftwareVersion -gt '6.8'){
    $environment = $environment68
}else{
    $environment = 'kO365'
}
if($cluster.clusterSoftwareVersion -lt '6.6'){
    $entityTypes = 'kMailbox,kUser,kGroup,kSite,kPublicFolder'
}else{
    $entityTypes = 'kMailbox,kUser,kGroup,kSite,kPublicFolder,kO365Exchange,kO365OneDrive,kO365Sharepoint'
}

$rootSource = api get "protectionSources/rootNodes?environments=kO365" | Where-Object {$_.protectionSource.name -eq $sourceName}
if(! $rootSource){
    Write-Host "protection source $sourceName not found" -ForegroundColor Yellow
    exit
}

$source = api get "protectionSources?id=$($rootSource.protectionSource.id)&excludeOffice365Types=$entityTypes&allUnderHierarchy=false"
$objectsNode = $source.nodes | Where-Object {$_.protectionSource.name -eq $nodeString}
if(!$objectsNode){
    Write-Host "Source $sourceName is not configured for O365 $objectString" -ForegroundColor Yellow
    exit
}

$unprotectedIndex = @()
$protectedIndex = @()
$nodeIdIndex = @()
$lastCursor = 0
$unprotectedObjects = @()

$jobs = (api get -v2 "data-protect/protection-groups?environments=kO365&isActive=true&isDeleted=false").protectionGroups | Where-Object {$_.office365Params.protectionTypes -eq $objectKtype}

$protectedIndex = @($jobs.office365Params.objects.id | Where-Object {$_ -ne $null} | Sort-Object -Unique)
$unprotectedIndex = @($jobs.office365Params.excludeObjectIds | Where-Object {$_ -ne $null -and $_ -notin $protectedIndex} | Sort-Object -Unique)

$objects = api get "protectionSources?pageSize=50000&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false$($queryParam)&useCachedData=false"
$cursor = $objects.entityPaginationParameters.beforeCursorEntityId
if($objectsNode.protectionSource.id -in $protectedIndex){
    $autoProtected = $True
}

# enumerate objects
while(1){
    foreach($node in $objects.nodes){
        $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
        if($autoProtected -eq $True -and $node.protectionSource.id -notin $unprotectedIndex){
            $protectedIndex = @($protectedIndex + $node.protectionSource.id)
        }
        if($autoProtected -ne $True -and $node.protectionSource.id -notin $protectedIndex){
            $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
            $unprotectedObjects = @($unprotectedObjects + $node.protectionSource.name)
            "$($node.protectionSource.name),$($node.protectionSource.office365ProtectionSource.primarySMTPAddress),$($node.protectionSource.office365ProtectionSource.webUrl),$($node.protectionSource.office365ProtectionSource.uuid)" | Out-File -FilePath $outfileName -Append
        }
        $lastCursor = $node.protectionSource.id
    }
    if($cursor){
        $objects = api get "protectionSources?pageSize=50000&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false$($queryParam)&useCachedData=false&afterCursorEntityId=$cursor"
        $cursor = $objects.entityPaginationParameters.beforeCursorEntityId
    }else{
        break
    }
    # patch for 6.8.1
    if($objects.nodes -eq $null){
        if($cursor -gt $lastCursor){
            $node = api get "protectionSources?id=$cursor$($queryParam)"
            $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
            if($autoProtected -eq $True -and $node.protectionSource.id -notin $unprotectedIndex){
                $protectedIndex = @($protectedIndex + $node.protectionSource.id)
            }
            if($autoProtected -ne $True -and $node.protectionSource.id -notin $protectedIndex){
                $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
            }
            $lastCursor = $node.protectionSource.id
        }
    }
    if($cursor -eq $lastCursor){
        break
    }
}

$nodeIdIndex = @($nodeIdIndex | Sort-Object -Unique)
$protectedIndex = @($protectedIndex | Sort-Object -Unique)
$unprotectedIndex = @($unprotectedIndex | Sort-Object -Unique)

$objectCount = $nodeIdIndex.Count
$protectedCount = $protectedIndex.Count
$unprotectedCount = $unprotectedIndex.Count

if($unprotectedCount -gt 0){
    Write-Host "`nUnprotected $($objectString):`n"
    Write-Host "$(($unprotectedObjects | Sort-Object) -join "`n")"
}

Write-Host "`n$objectCount $objectString discovered ($protectedCount protected, $unprotectedCount unprotected)`n"
Write-Host "Output saved to $outfilename`n"