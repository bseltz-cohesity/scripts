# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][array]$mailboxes,  # optional names of mailboxes unprotect
    [Parameter()][string]$mailboxList = '',  # optional textfile of mailboxes to unprotect
    [Parameter()][int]$pageSize = 50000,
    [Parameter()][switch]$deleteSnapshots
)

# gather list of mailboxes to unprotect
$mailboxesToUnprotect = @()
foreach($mailbox in $mailboxes){
    $mailboxesToUnprotect += $mailbox
}
if ('' -ne $mailboxList){
    if(Test-Path -Path $mailboxList -PathType Leaf){
        $mailboxes = Get-Content $mailboxList
        foreach($mailbox in $mailboxes){
            $mailboxesToUnprotect += [string]$mailbox
        }
    }else{
        Write-Host "mailbox list $mailboxList not found!" -ForegroundColor Yellow
        exit
    }
}

$mailboxesToUnprotect = @($mailboxesToUnprotect | Where-Object {$_ -ne ''})

if($mailboxesToUnprotect.Count -eq 0){
    Write-Host "No mailboxes specified" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -regionid $region

# find O365 source
$rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365").sources | Where-Object name -eq $sourceName

if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}

$rootSourceId = $rootSource[0].sourceInfoList[0].sourceId

$source = api get "protectionSources?id=$($rootSourceId)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false"  # -region $regionId
$usersNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
if(!$usersNode){
    Write-Host "Source $sourceName is not configured for O365 Mailboxes" -ForegroundColor Yellow
    exit
}

$nameIndex = @{}
$smtpIndex = @{}
$uuidIndex = @{}
$idIndex = @{}
$users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false"  # -region $regionId
while(1){
    foreach($node in $users.nodes){
        # Write-Host "$($node.protectionSource.name) $($node.protectionSource.office365ProtectionSource.uuid)"
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        $idIndex["$($node.protectionSource.id)"] = $node.protectionSource.name
        $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
        $uuidIndex[$node.protectionSource.office365ProtectionSource.uuid] = $node.protectionSource.id
    }
    $cursor = $users.nodes[-1].protectionSource.id
    $users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false&afterCursorEntityId=$cursor"  # -region $regionId
    if(!$users.PSObject.Properties['nodes'] -or $users.nodes.Count -eq 1){
        break
    }
}  

if($deleteSnapshots){
    $delSnaps = $True
}else{
    $delSnaps = $false
}

foreach($mailbox in $mailboxesToUnprotect){
    $userId = $null
    if($mailbox -ne $null -and $smtpIndex.ContainsKey($mailbox)){
        $userId = $smtpIndex[$mailbox]
    }elseif($mailbox -ne $null -and $nameIndex.ContainsKey($mailbox)){
        $userId = $nameIndex[$mailbox]
    }elseif($mailbox -ne $null -and $uuidIndex.ContainsKey($mailbox)){
        $userId = $uuidIndex[$mailbox]
    }
    if($userId){
        $unprotectParams = @{
            "action" = "UnProtect";
            "objectActionKey" = "kO365Exchange";
            "unProtectParams" = @{
                "objects" = @(
                    @{
                        "id" = $userId;
                        "deleteAllSnapshots" = $delSnaps;
                        "forceUnprotect" = $true
                    }
                )
            }
        }
        Write-Host "Unprotecting $mailbox"
        $null = api post -v2 data-protect/protected-objects/actions $unprotectParams
    }else{
        Write-Host "Mailbox $mailbox not found" -ForegroundColor Yellow
    }
}
