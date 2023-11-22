# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][switch]$enable,
    [Parameter()][switch]$disable,
    [Parameter()][int]$days = 1
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

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

$cluster = api get cluster
$isRTEnabled = $cluster.reverseTunnelEnabled

if($enable){
    $endDate = (Get-Date).AddDays($days)
    Write-Host "`nEnabling Support Channel until $($endDate)...`n"
    $endDateUsecs = dateToUsecs $endDate
    $endDateMsecs = [Int64][math]::round($endDateUsecs / 1000, 0)
    $rtParams = @{
        "enableReverseTunnel" = $True;
        "reverseTunnelEnableEndTimeMsecs" = $endDateMsecs
    }
    $null = api put /reverseTunnel $rtParams
}elseif($disable){
    Write-Host "`nDisabling Support Channel...`n"
    $rtParams = @{
        "enableReverseTunnel" = $false;
        "reverseTunnelEnableEndTimeMsecs" = 0
    }
    $null = api put /reverseTunnel $rtParams
}else{
    if($isRTEnabled){
        $endDate = usecsToDate ($cluster.reverseTunnelEndTimeMsecs * 1000)
        Write-Host "`nSupport Channel is enabled until $endDate`n"
    }else{
        Write-Host "`nSupport Channel is disabled`n"
    }
}

if(! $disable -and ($enable -or $isRTEnabled -eq $True)){
    $supportUserToken = ''
    while($supportUserToken -eq ''){
        if($enable){
            Start-Sleep 2
        }
        $linuxUser = api put users/linuxSupportUserBashShellAccess
        $supportUserToken = $linuxUser.supportUserToken
    }
    Write-Host "Please provide the below to Cohesity Support"
    Write-Host "`nCluster ID and Token for Cluster: $($cluster.name) (expires $endDate)`n$($cluster.id) $($supportUserToken)`n" -ForegroundColor Cyan
}
