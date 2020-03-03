[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$password
)

. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
storePasswordFromInput -vip $vip -username $username -domain $domain -password $password
