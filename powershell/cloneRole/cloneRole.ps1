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
    [Parameter()][string]$targetCluster,
    [Parameter()][string]$targetUsername,
    [Parameter()][string]$targetDomain = 'local',
    [Parameter(Mandatory = $True)][string]$roleName,
    [Parameter()][string]$newRoleName
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
if(!$targetCluster -and !$newRoleName){
    Write-Host "-newRoleName is required" -ForegroundColor Yellow
    exit
}
if($newRoleName){
    $newRole.name = $newRoleName
    $newRole.label = $newRoleName
}
if($targetCluster -and $targetUsername){
    apiauth -vip $targetCluster -username $targetUsername -domain $targetDomain
    "Cloning role `'$($role.name)`' to `'$($newRole.name)`' on $targetCluster..."
}else{
    "Cloning role `'$($role.name)`' to `'$($newRole.name)`'..."
}
$null = api post roles $newRole
