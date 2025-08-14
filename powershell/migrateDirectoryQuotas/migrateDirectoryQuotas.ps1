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
    [Parameter()][string]$clusterName,
    [Parameter()][string]$oldViewName,
    [Parameter()][string]$newViewName,
    [Parameter()][int64]$pageCount = 1000
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

$cookie = $null
while($True){
    if($cookie){
        $quotas = api get "viewDirectoryQuotas?viewName=$oldViewName&pageCount=$pageCount&cookie=$cookie"
    }else{
        $quotas = api get "viewDirectoryQuotas?viewName=$oldViewName&pageCount=$pageCount"
    }
    if(! $quotas.quotas){
        Write-Host "No quotas found"
    }

    foreach($quota in $quotas.quotas){
        if(!$quota.policy.PSObject.Properties['alertLimitBytes'] -or $quota.policy.alertLimitBytes -eq $null){
            $alertLimitBytes = $quota.policy.hardLimitBytes * 0.9
        }else{
            $alertLimitBytes = $quota.policy.alertLimitBytes
        }
        $quotaParams = @{
            "viewName" = $newViewName;
            "quota"    = @{
                "dirPath" = $quota.dirPath;
                "policy"  = @{
                    "hardLimitBytes"  = $quota.policy.hardLimitBytes;
                    "alertLimitBytes" = $alertLimitBytes
                }
            }
        }
        # put new quota
        Write-Host "Setting directory quota on $($newViewName)$($quota.dirpath)..."
        $null = api put viewDirectoryQuotas $quotaParams
    }

    if($quotas.PSObject.Properties['cookie']){
        $cookie = $quotas.cookie
    }else{
        break
    }
}
