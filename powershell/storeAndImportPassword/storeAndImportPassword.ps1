# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password = '',
    [Parameter()][string]$key = $null,
    [Parameter()][switch]$import
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if($import){
    if(!$key){
        Write-Host "Key required for import" -foregroundcolor Yellow
        exit
    }
    $apiKey = $false
    if($useApiKey){
        $apiKey = $True
    }
    importStoredPassword -vip $vip -username $username -domain $domain -key $key -useApiKey $apiKey
}else{
    storePasswordForUser -vip $vip -username $username -domain $domain -passwd $password
}
