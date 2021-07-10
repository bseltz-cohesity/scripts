### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # dns or ip of couhesity
    [Parameter(Mandatory = $True)][string]$username,  # cohesity username
    [Parameter()][string]$domain = 'local',      # local or AD domain (fqdn)
    [Parameter(Mandatory = $True)][string]$o365source,
    [Parameter(Mandatory = $True)][string]$o365user,
    [Parameter(Mandatory = $True)][string]$o365pwd,
    [Parameter(Mandatory = $True)][array]$appId,
    [Parameter(Mandatory = $True)][array]$appSecretKey
)

if($appId.Count -ne $appSecretKey.Count){
    Write-Host "must include the same number of appIds and appSecretKeys" -ForegroundColor Yellow
    exit 1
}

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
            "msGraphCredentialsVec" = @()
        };
        "endpoint"           = $source.registeredEntityInfo.connectorParams.endpoint;
        "useOutlookEwsOauth" = $source.registeredEntityInfo.connectorParams.additionalParams.useOutlookEwsOauth;
        "office365Region"    = "Default"
    }
}

$i = 0
foreach($id in $appId){
    $msGraphCredential = $source.registeredEntityInfo.connectorParams.credentials.msGraphCredentialsVec | Where-Object {$_.clientId -eq $id}
    if(!$msGraphCredential){
        Write-Host "appId $id not found"
        exit 1
    }else{
        $sourceParams.entityInfo.credentials.msGraphCredentialsVec += @{
            "clientId" = $id;
            "grantType" = $msGraphCredential.grantType;
            "scope" = $msGraphCredential.scope;
            "clientSecret" = $appSecretKey[$i]
        }
    }
    $i += 1
}

Write-Host "Updating O365 credentials..."
$null = api put "/backupsources/$($source.entity.id)" $sourceParams
