# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$outFolder = '.'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -heliosAuthentication $mcm -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfile = $(Join-Path -Path $outFolder -ChildPath "heliosUsers-$dateString.csv")
"""Email Address"",""Username"",""Firstname"",""Lastname"",""Roles"",""Clusters"",""Created"",""Last Updated""" | Out-File -FilePath $outfile

$roles = api get mcm/roles
$users = api get mcm/users

foreach($user in $users){
    $user.username
    $userRoles = @()
    foreach($userRole in $user.roles){
        $role = $roles | Where-Object name -eq $userRole
        $userRoles = @($userRoles + $role.label)
    }
    $userClusters = @()
    foreach($userCluster in $user.clusterIdentifiers){
        $clusterId = $userCluster.clusterId
        $cluster = heliosClusters | Where-Object clusterId -eq $clusterId
        $userClusters = @($userClusters + $cluster.name)
    }
    """$($user.emailAddress)"",""$($user.username)"",""$($user.firstName)"",""$($user.lastName)"",""$($userRoles -join '; ')"",""$($userClusters -join '; ')"",""$(usecsToDate ($user.createdTimeMsecs * 1000))"",""$(usecsToDate ($user.lastUpdatedTimeMsecs * 1000))""" | Out-File -FilePath $outfile -Append
}

"`nOutput saved to $outfile`n"
