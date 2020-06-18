### usage: ./directoryQuota.ps1 -vip mycluster `
#                               -username myusername `
#                               -domain mydomain.net `
#                               -viewName myview `
#                               -path /mydir `
#                               -quotaLimitGB 20 `
#                               -quotaAlertGB 18

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter(Mandatory = $True)][string]$path,
    [Parameter(Mandatory = $True)][int64]$quotaLimitGB,
    [Parameter(Mandatory = $True)][int64]$quotaAlertGB
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# validate view name
$view = (api get views).views | Where-Object name -eq $viewName

if(! $view){
    Write-Host "View $viewName not found" -ForegroundColor Yellow
    exit 1
}

# convert to Bytes
$quotaLimitBytes = $quotaLimitGB * 1024 * 1024 * 1024
$quotaAlertBytes = $quotaAlertGB * 1024 * 1024 * 1024

# set new quota parameters
$quotaParams = @{
    "viewName" = $viewName;
    "quota"    = @{
        "dirPath" = $path;
        "policy"  = @{
            "hardLimitBytes"  = $quotaLimitBytes;
            "alertLimitBytes" = $quotaAlertBytes
        }
    }
}

# put new quota
Write-Host "Setting directory quota on $viewName/$path to $quotaLimitGB GB..."
$null = api put viewDirectoryQuotas $quotaParams
