# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

# outfile
$cluster = api get cluster
$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = "roles-$($cluster.name)-$dateString.csv"

$roles = api get roles
foreach($role in $roles){
    setApiProperty -object $role -name createdTime -value (usecsToDate ($role.createdTimeMsecs * 1000))
    setApiProperty -object $role -name lastUpdatedTime -value (usecsToDate ($role.lastUpdatedTimeMsecs * 1000))
    delApiProperty -object $role -name createdTimeMsecs
    delApiProperty -object $role -name lastUpdatedTimeMsecs
    delApiProperty -object $role -name tenantIds
    foreach($priv in $role.privileges){
        setApiProperty -object $role -name $priv -value $True 
    }
    delApiProperty -object $role -name privileges
}

$roles | Export-CSV -Path $outfileName
Write-Host "`nReport saved to $outfileName`n"

