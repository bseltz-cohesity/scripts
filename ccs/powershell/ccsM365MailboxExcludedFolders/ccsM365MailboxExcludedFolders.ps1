# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][int]$pageSize = 10000
)

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "excludedFolders-$dateString.tsv"
"Mailbox Name`tSMTP Address`tExcluded Folders" | Out-File -FilePath $outfileName -Encoding utf8

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -regionid $region

# find O365 source
$rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365&excludeProtectionStats=true").sources | Where-Object name -eq $sourceName

if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}

$rootSourceId = $rootSource[0].sourceInfoList[0].sourceId

$source = api get "protectionSources?id=$($rootSourceId)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false"

$usersNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
if(!$usersNode){
    Write-Host "Source $sourceName is not configured for O365 Mailboxes" -ForegroundColor Yellow
    exit
}

$protectionCache = @{}

$users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false"
$count = 1
while(1){
    foreach($node in $users.nodes){        
        if($node.PSObject.Properties['objectProtectionInfo']){
            $entityId = $node.objectProtectionInfo.entityId
            if($node.objectProtectionInfo.PSObject.Properties['autoProtectParentId']){
                $autoProtectParentId = $node.objectProtectionInfo.autoProtectParentId
                if($protectionCache.ContainsKey("$autoProtectParentId")){
                    $protectedObject = $protectionCache["$autoProtectParentId"]
                }else{
                    $protectedObject = api get -v2 "data-protect/objects?objectActionKeys=kO365Exchange&ids=$autoProtectParentId"
                    $protectionCache["$autoProtectParentId"] = $protectedObject
                }
            }else{
                $protectedObject = api get -v2 "data-protect/objects?objectActionKeys=kO365Exchange&ids=$entityId"
            }
            $excludedFolders = $protectedObject.objects[0].objectBackupConfiguration.office365Params.userMailboxObjectProtectionParams.excludeFolders
            Write-Host "$($count): $($node.protectionSource.office365ProtectionSource.primarySMTPAddress)`t$($excludedFolders -join ', ')"
            "$($node.protectionSource.name)`t$($node.protectionSource.office365ProtectionSource.primarySMTPAddress)`t$($excludedFolders -join ', ')" | Out-File -FilePath $outfileName -Append
            $count+= 1
        }
    }
    $cursor = $users.nodes[-1].protectionSource.id
    $users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false&afterCursorEntityId=$cursor"  # -region $regionId
    if(!$users.PSObject.Properties['nodes'] -or $users.nodes.Count -eq 1){
        break
    }
}

Write-Host "`nOutput saved to $outfilename`n"
