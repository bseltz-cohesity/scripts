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
    [Parameter()][string]$jobName,
    [Parameter()][ValidateSet('mailbox','onedrive','sites','teams','publicfolders','all')][string]$objectType = 'all'
)

if($objectType -eq 'mailbox'){
    $objectString = 'Mailboxes'
    $nodeString = 'users'
    $objectKtype = 'kMailbox'
    $environment68 = 'kO365Exchange'
    $queryParam = '&hasValidMailbox=true&hasValidOnedrive=false'
}elseif($objectType -eq 'onedrive'){
    $objectString = 'OneDrives'
    $nodeString = 'users'
    $objectKtype = 'kOneDrive'
    $environment68 = 'kO365OneDrive'
    $queryParam = '&hasValidOnedrive=true&hasValidMailbox=false'
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
}

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

$cluster = api get cluster
if($cluster.clusterSoftwareVersion -gt '6.8'){
    $environment = 'kO365OneDrive'
}else{
    $environment = 'kO365'
}
if($cluster.clusterSoftwareVersion -lt '6.6'){
    $entityTypes = 'kMailbox,kUser,kGroup,kSite,kPublicFolder'
}else{
    $entityTypes = 'kMailbox,kUser,kGroup,kSite,kPublicFolder,kO365Exchange,kO365OneDrive,kO365Sharepoint'
}

# get the protectionJob
$jobs = (api get -v2 "data-protect/protection-groups?environments=kO365").protectionGroups | Where-Object {$_.isDeleted -ne $True -and $_.isActive -eq $True}
if($objectType -ne 'all'){
    $jobs = $jobs | Where-Object {$_.office365Params.protectionTypes -eq $objectKtype}
}

if(!$jobs){
    Write-Host "No jobs found for O365 ($objectType)"
    exit
}

# build source ID index
$sourceIdIndex = @{}
$lastCursor = 0

$jobFound = $false
foreach($job in $jobs | Where-Object {$_.isDeleted -ne $True -and $_.isActive -eq $True} | Sort-Object -Property name){
    if((! $jobName) -or $job.name -eq $jobName){
        $sourceId = $job.office365Params.sourceId
        if("$sourceId" -notin $sourceIdIndex.Keys){
            $sourceIdIndex["$sourceId"] = @{'mailboxes' = @(); 'onedrives' = @(); 'other' = @()}
            $rootSource = api get "protectionSources/rootNodes?environments=kO365&id=$sourceId"
            $sourceIdIndex["$sourceId"]['other'] = @($sourceIdIndex["$sourceId"]['other'] + $rootSource.protectionSource.id)
            $sourceIdIndex["$sourceId"]['mailboxes'] = @($sourceIdIndex["$sourceId"]['mailboxes'] + $rootSource.protectionSource.id)
            $sourceIdIndex["$sourceId"]['onedrives'] = @($sourceIdIndex["$sourceId"]['onedrives'] + $rootSource.protectionSource.id)
            $source = api get "protectionSources?id=$($rootSource.protectionSource.id)&excludeOffice365Types=$entityTypes&allUnderHierarchy=false"
            foreach($objectNode in $source.nodes){
                if($objectNode.protectionSource.office365ProtectionSource.name -eq 'Users'){
                    if($objectType -in @('all', 'mailbox', 'onedrive')){
                        Write-Host "`nDiscovering $($objectNode.protectionSource.office365ProtectionSource.name) from $($rootSource.protectionSource.name)"
                    }
                    # get mailboxes
                    if($objectType -in @('all', 'mailbox')){
                        $sourceIdIndex["$sourceId"]['mailboxes'] = @($sourceIdIndex["$sourceId"]['mailboxes'] + $objectNode.protectionSource.id)
                        $objects = api get "protectionSources?pageSize=50000&nodeId=$($objectNode.protectionSource.id)&id=$($objectNode.protectionSource.id)&allUnderHierarchy=false&hasValidMailbox=true&hasValidOnedrive=false&useCachedData=false"
                        $cursor = $objects.entityPaginationParameters.beforeCursorEntityId
                        while(1){
                            foreach($node in $objects.nodes){
                                $sourceIdIndex["$sourceId"]['mailboxes'] = @($sourceIdIndex["$sourceId"]['mailboxes'] + $node.protectionSource.id)
                                $lastCursor = $node.protectionSource.id
                            }
                            Write-Host "    $(@($sourceIdIndex["$sourceId"]['mailboxes']).Count) Mailboxes"
                            if($cursor){
                                $objects = api get "protectionSources?pageSize=50000&nodeId=$($objectNode.protectionSource.id)&id=$($objectNode.protectionSource.id)&allUnderHierarchy=false&useCachedData=false&hasValidMailbox=true&hasValidOnedrive=false&afterCursorEntityId=$cursor"
                                $cursor = $objects.entityPaginationParameters.beforeCursorEntityId
                            }else{
                                break
                            }
                            # patch for 6.8.1
                            if($objects.nodes -eq $null){
                                if($cursor -gt $lastCursor){
                                    $node = api get "protectionSources?id=$cursor&hasValidMailbox=true&hasValidOnedrive=false"
                                    $sourceIdIndex["$sourceId"]['mailboxes'] = @($sourceIdIndex["$sourceId"]['mailboxes'] + $node.protectionSource.id)
                                    $lastCursor = $node.protectionSource.id
                                }
                            }
                            if($cursor -eq $lastCursor){
                                break
                            }
                        }
                    }
                    # get onedrives
                    if($objectType -in @('all', 'onedrive')){
                        $sourceIdIndex["$sourceId"]['onedrives'] = @($sourceIdIndex["$sourceId"]['onedrives'] + $objectNode.protectionSource.id)
                        $objects = api get "protectionSources?pageSize=50000&nodeId=$($objectNode.protectionSource.id)&id=$($objectNode.protectionSource.id)&allUnderHierarchy=false&hasValidOnedrive=true&useCachedData=false"
                        $cursor = $objects.entityPaginationParameters.beforeCursorEntityId
                        while(1){
                            foreach($node in $objects.nodes){
                                $sourceIdIndex["$sourceId"]['onedrives'] = @($sourceIdIndex["$sourceId"]['onedrives'] + $node.protectionSource.id)
                                $lastCursor = $node.protectionSource.id
                            }
                            Write-Host "    $(@($sourceIdIndex["$sourceId"]['onedrives']).Count) OneDrives"
                            if($cursor){
                                $objects = api get "protectionSources?pageSize=50000&nodeId=$($objectNode.protectionSource.id)&id=$($objectNode.protectionSource.id)&allUnderHierarchy=false&hasValidOnedrive=true&useCachedData=false&afterCursorEntityId=$cursor"
                                $cursor = $objects.entityPaginationParameters.beforeCursorEntityId
                            }else{
                                break
                            }
                            # patch for 6.8.1
                            if($objects.nodes -eq $null){
                                if($cursor -gt $lastCursor){
                                    $node = api get "protectionSources?id=$cursor&hasValidOnedrive=true&hasValidMailbox=false"
                                    $sourceIdIndex["$sourceId"]['onedrives'] = @($sourceIdIndex["$sourceId"]['onedrives'] + $node.protectionSource.id)
                                    $lastCursor = $node.protectionSource.id
                                }
                            }
                            if($cursor -eq $lastCursor){
                                break
                            }
                        }
                    }
                }else{
                    if($objectType -notin @('mailbox', 'onedrive')){
                        Write-Host "`nDiscovering $($objectNode.protectionSource.office365ProtectionSource.name) from $($rootSource.protectionSource.name)"
                        $sourceIdIndex["$sourceId"]['other'] = @($sourceIdIndex["$sourceId"]['other'] + $objectNode.protectionSource.id)
                        $objects = api get "protectionSources?pageSize=50000&nodeId=$($objectNode.protectionSource.id)&id=$($objectNode.protectionSource.id)&allUnderHierarchy=false&useCachedData=false"
                        $cursor = $objects.entityPaginationParameters.beforeCursorEntityId
                        while(1){
                            foreach($node in $objects.nodes){
                                $sourceIdIndex["$sourceId"]['other'] = @($sourceIdIndex["$sourceId"]['other'] + $node.protectionSource.id)
                                $lastCursor = $node.protectionSource.id
                            }
                            Write-Host "    $(@($sourceIdIndex["$sourceId"]['other']).Count)"
                            if($cursor){
                                $objects = api get "protectionSources?pageSize=50000&nodeId=$($objectNode.protectionSource.id)&id=$($objectNode.protectionSource.id)&allUnderHierarchy=false&useCachedData=false&afterCursorEntityId=$cursor"
                                $cursor = $objects.entityPaginationParameters.beforeCursorEntityId
                            }else{
                                break
                            }
                            # patch for 6.8.1
                            if($objects.nodes -eq $null){
                                if($cursor -gt $lastCursor){
                                    $node = api get protectionSources?id=$cursor
                                    $sourceIdIndex["$sourceId"]['other'] = @($sourceIdIndex["$sourceId"]['other'] + $node.protectionSource.id)
                                    $lastCursor = $node.protectionSource.id
                                }
                            }
                            if($cursor -eq $lastCursor){
                                break
                            }
                        }
                    }
                }
            }
        }
    }
}
Write-Host "`nReviewing Protection Groups...`n"

# updage protection groups
foreach($job in $jobs | Where-Object isDeleted -ne $True | Sort-Object -Property name){
    if((! $jobName) -or $job.name -eq $jobName){
        if($job.office365Params.protectionTypes -eq 'kOneDrive'){
            $objIndex = $sourceIdIndex["$sourceId"]['onedrives']
        }elseif($job.office365Params.protectionTypes -eq 'kMailbox'){
            $objIndex = $sourceIdIndex["$sourceId"]['mailboxes']
        }else{
            $objIndex = $sourceIdIndex["$sourceId"]['other']
        }
        $jobFound = $True
        $protectedCount = @($job.office365Params.objects).Count
        $job.office365Params.objects = @($job.office365Params.objects | Where-Object {$_.id -in $objIndex})
        $newProtectedCount = @($job.office365Params.objects).Count
        if($newProtectedCount -lt $protectedCount){
            Write-Host  "    $($job.name) (updated)" -ForegroundColor Yellow
            $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
        }else{
            Write-Host "    $($job.name) (unchanged)"
        }
    }
}
if($jobName -and $jobFound -eq $false){
    Write-Host "$jobName not found" -foregroundcolor Yellow
}

Write-Host ""

