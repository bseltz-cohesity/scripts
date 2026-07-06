# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][array]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][array]$clusterName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)


# example get-report function
function get-report(){
    $cluster = api get cluster
    Write-Host "$($cluster.name)  $($cluster.clusterSoftwareVersion)"
}


# authentication =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        Write-Host "$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if(! $USING_HELIOS -and $useApiKey -and $password){
        # cluster API key specified on the command line won't work for multiple clusters
        $password = $null
    }
    if($USING_HELIOS){
        if(! $clusterName){
            # get all Helios Clusters if cluster names were not specified on the command line
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName){
            $null = heliosCluster $c
            get-report # use our get-report function for this cluster
        }
    }else{
        get-report # use our get-report function for this cluster
    }
}
