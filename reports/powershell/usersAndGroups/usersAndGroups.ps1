# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# outfile
$cluster = api get cluster
$outfileName = "$($cluster.name)-usersAndGroups.csv"

# headings
"""Type"",""Principal"",""Domain"",""Roles""" | Out-File -FilePath $outfileName

$roles = api get roles
$users = api get users?_includeTenantInfo=true
$groups = api get groups?_includeTenantInfo=true

foreach($user in $users | Sort-Object -Property domain, username){
    Write-Host "User: $($user.domain)\$($user.username)"
    $roleNames = @()
    foreach($role in $user.roles){
        $roleName = ($roles | Where-Object name -eq $role).label
        $roleNames = @($roleNames + $roleName)
    }
    """User"",""$($user.username)"",""$($user.domain)"",""$($roleNames -join '; ')""" | Out-File -FilePath $outfileName -Append
}

foreach($group in $groups | Sort-Object -Property domain, name){
    Write-Host "Group: $($group.domain)\$($group.name)"
    $roleNames = @()
    foreach($role in $group.roles){
        $roleName = ($roles | Where-Object name -eq $role).label
        $roleNames = @($roleNames + $roleName)
    }
    """Group"",""$($group.name)"",""$($group.domain)"",""$($roleNames -join '; ')""" | Out-File -FilePath $outfileName -Append
}

"`nOutput saved to $outfilename`n"
