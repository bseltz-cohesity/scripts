# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password = ''
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    storePasswordInFile -vip $vip -username $username -domain $domain -password $password -useApiKey
}else{
    storePasswordInFile -vip $vip -username $username -domain $domain -password $password
}
