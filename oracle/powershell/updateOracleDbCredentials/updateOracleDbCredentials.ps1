### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$oracleServer,
    [Parameter(Mandatory = $True)][string]$oracleUser,
    [Parameter(Mandatory = $True)][string]$oraclePwd
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$sources = api get /backupsources?envTypes=19
if($sources){
    $source = $sources.entityHierarchy.children[0].children | Where-Object {$_.entity.displayName -eq $oracleServer}
}

if(!$source){
    Write-Host "Oracle server $oracleServer not found!" -ForegroundColor Yellow
    exit 1
}

$sourceParams = @{
    "appEnvVec"           = @(
        19
    );
    "usesPersistentAgent" = $true;
    "ownerEntity"         = $source.entity;
    "appCredentialsVec"   = @(
        @{
            "envType"     = 19;
            "credentials" = @{
                "username" = $oracleUser;
                "password" = $oraclePwd
            }
        }
    )
}

$result = api put /applicationSourceRegistration $sourceParams
if($result -eq $true){
    Write-Host "DB credentials updated"
}else{
    Write-Host "Something went wrong" -ForegroundColor Yellow
}
