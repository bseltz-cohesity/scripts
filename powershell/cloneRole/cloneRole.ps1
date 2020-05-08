### usage: 
# ./clonerole.ps1 -vip mycluster 
#                 -username myusername 
#                 -domain mydomain.net 
#                 -roleName role1 
#                 -newRoleName role2

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$roleName,
    [Parameter(Mandatory = $True)][string]$newRoleName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$role = api get roles | Where-Object name -eq $roleName

if(! $role){
    Write-Host "Role `'$roleName`' not found!" -ForegroundColor Yellow
    exit
}

$newRole = $role
$newRole.name = $newRoleName
$newRole.label = $newRoleName
"Cloning role `'$roleName`' to `'$newRoleName`'..."
$null = api post roles $newRole
