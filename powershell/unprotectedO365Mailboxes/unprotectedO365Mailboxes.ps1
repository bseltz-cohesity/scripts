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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory = $True)][string]$sourceName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region

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

Write-Host "`nDiscovering mailboxes..."

$cluster = api get cluster
if($cluster.clusterSoftwareVersion -gt '6.8'){
    $environment = 'kO365Exchange'
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
$mailboxesNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'users'}
if(!$mailboxesNode){
    Write-Host "Source $sourceName is not configured for O365 mailboxes" -ForegroundColor Yellow
    exit
}

$nameIndex = @{}
$smtpIndex = @{}
$unprotectedIndex = @()
$protectedIndex = @()
$nodeIdIndex = @()
$lastCursor = 0
$unprotectedMailboxes = @()

$jobs = (api get -v2 "data-protect/protection-groups?environments=kO365&isActive=true&isDeleted=false").protectionGroups | Where-Object {$_.office365Params.protectionTypes -eq 'kMailbox'}

$protectedIndex = @($jobs.office365Params.objects.id | Where-Object {$_ -ne $null})
$unprotectedIndex = @($jobs.office365Params.excludeObjectIds | Where-Object {$_ -ne $null -and $_ -notin $protectedIndex})

$mailboxes = api get "protectionSources?pageSize=50000&nodeId=$($mailboxesNode.protectionSource.id)&id=$($mailboxesNode.protectionSource.id)&allUnderHierarchy=false&hasValidMailbox=true&useCachedData=false"
$cursor = $mailboxes.entityPaginationParameters.beforeCursorEntityId
if($mailboxesNode.protectionSource.id -in $protectedIndex){
    $autoProtected = $True
}

# enumerate mailboxes
while(1){
    foreach($node in $mailboxes.nodes){
        $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
        if($autoProtected -eq $True -and $node.protectionSource.id -notin $unprotectedIndex){
            $protectedIndex = @($protectedIndex + $node.protectionSource.id)
        }
        if($autoProtected -ne $True -and $node.protectionSource.id -notin $protectedIndex){
            $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
            $unprotectedMailboxes = @($unprotectedMailboxes + $node.protectionSource.name)
        }
        $lastCursor = $node.protectionSource.id
    }
    if($cursor){
        $mailboxes = api get "protectionSources?pageSize=50000&nodeId=$($mailboxesNode.protectionSource.id)&id=$($mailboxesNode.protectionSource.id)&allUnderHierarchy=false&hasValidMailbox=true&useCachedData=false&afterCursorEntityId=$cursor"
        $cursor = $mailboxes.entityPaginationParameters.beforeCursorEntityId
    }else{
        break
    }
    # patch for 6.8.1
    if($mailboxes.nodes -eq $null){
        if($cursor -gt $lastCursor){
            $node = api get protectionSources?id=$cursor
            $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
            $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
            $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
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

$mailboxCount = $nodeIdIndex.Count
$protectedCount = $protectedIndex.Count
$unprotectedCount = $unprotectedIndex.Count

Write-Host "`n$($nodeIdIndex.Count) mailboxes discovered ($($protectedIndex.Count) protected, $($unprotectedIndex.Count) unprotected)`n"

if($unprotectedCount -gt 0){
    Write-Host "Unprotected Mailboxes:`n"
    Write-Host "$(($unprotectedMailboxes | Sort-Object) -join "`n")`n"
}

