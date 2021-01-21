### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$o365source,
    [Parameter(Mandatory = $True)][string]$o365user,
    [Parameter(Mandatory = $True)][string]$o365pwd,
    [Parameter(Mandatory = $True)][string]$appId,
    [Parameter(Mandatory = $True)][string]$appSecretKey
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$sources = api get /backupsources?envTypes=24
if($sources){
    $source = $sources.entityHierarchy.children | Where-Object {$_.entity.displayName -eq $o365source}
}

if(!$source){
    Write-Host "O365 source $o365source not found!" -ForegroundColor Yellow
    exit 1
}

$sourceParams = @{
    "entity"     = $source.entity;
    "entityInfo" = @{
        "credentials"        = @{
            "username"              = $o365user;
            "password"              = $o365pwd;
            "msGraphCredentialsVec" = @(
                @{
                    "clientId"     = $appId;
                    "grantType"    = $source.registeredEntityInfo.connectorParams.credentials.msGraphCredentialsVec[0].grantType;
                    "scope"        = $source.registeredEntityInfo.connectorParams.credentials.msGraphCredentialsVec[0].scope;
                    "clientSecret" = $appSecretKey
                }
            )
        };
        "endpoint"           = $source.registeredEntityInfo.connectorParams.endpoint;
        "useOutlookEwsOauth" = $source.registeredEntityInfo.connectorParams.additionalParams.useOutlookEwsOauth;
        "office365Region"    = "Default"
    }
}

Write-Host "Updating O365 credentials..."
$null = api put "/backupsources/$($source.entity.id)" $sourceParams
