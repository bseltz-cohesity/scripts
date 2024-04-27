### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter()][string]$username = 'admin',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password = $null,
    [Parameter()][string]$heliosVip = 'helios.cohesity.com',
    [Parameter()][string]$heliosUser = 'helios',
    [Parameter()][string]$heliosKey = $null
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
if($cohesity_api.api_version -lt '2023.09.22'){
    Write-Host "This script requires cohesity-api.ps1 version 2023.09.22 or later" -foregroundColor Yellow
    Write-Host "Please download it from https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api" -ForegroundColor Yellow
    exit
}

# connect to cluster to get cluster ID
Write-Host "`nConnecting to $vip"
apiauth -vip $vip -username $username -domain $domain -password $password -quiet
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

Write-Host "- Getting cluster ID"
$cluster = api get cluster
$clusterId = $cluster.id

# connect to helios to generate and download license
Write-Host "`nConnecting to $heliosVip"
apiauth -vip $heliosVip -username $heliosUser -password $heliosKey -quiet
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

Write-Host "- Generating new license"
$userInfo = api get /mcm/userInfo
$accountId = $userInfo.user.salesforceAccount.accountId
$licenseParams = @{
    "accountId" = $accountId;
    "clusterId" = $clusterId
}
$newLicense = api post -mcm licenses $licenseParams
fileDownload "https://$heliosVip/mcm/licenses?accountId=$accountId&clusterId=$clusterId" license

# connect to cluster to upload new license
Write-Host "`nConnecting to $vip"
apiauth -vip $vip -username $username -domain $domain -password $password -quiet
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

Write-Host "- Uploading license"
$result = fileUpload "https://$vip/irisservices/api/v1/nexus/license/upload" license
$cluster = api get cluster
setApiProperty -object $cluster -name 'licenseState' -value @{'state' = 'kClaimed'}
$null = api put cluster $cluster
Write-Host "`nCompleted`n"
