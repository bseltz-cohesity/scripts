### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$heliosVip = 'helios.cohesity.com',
    [Parameter()][string]$heliosUser = 'helios',
    [Parameter()][string]$heliosKey = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
if($cohesity_api.api_version -lt '2023.09.22'){
    Write-Host "This script requires cohesity-api.ps1 version 2023.09.22 or later" -foregroundColor Yellow
    Write-Host "Please download it from https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api" -ForegroundColor Yellow
    exit
}

# connect to cluster
Write-Host "`nConnecting to $vip"
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -noPromptForPassword $noPrompt -quiet
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# download license audit report
Write-Host "- Downloading license audit report"
$cluster = api get cluster
$clusterId = $cluster.id
$auditFileName = "AUDIT-REPORT-$($clusterId)" # -$((Get-Date).ToUniversalTime().ToString('hh-mm-ss'))"
fileDownload /nexus/license/audit $auditFileName

# connect to helios
Write-Host "`nConnecting to $heliosVip"
apiauth -vip $heliosVip -username $heliosUser -password $heliosKey -quiet
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# upload audit report
Write-Host "- Uploading license audit report"
$result = fileUpload "https://helios.cohesity.com/mcm/minos/licensing/v1/cluster/upload_audit_report" $auditFileName

# download new license
Write-Host "- Downloading new license key"
$userInfo = api get /mcm/userInfo
$accountId = $userInfo.user.salesforceAccount.accountId
$licenseFile = "license-$($clusterId)"
fileDownload "https://$heliosVip/mcm/licenses?accountId=$accountId&clusterId=$clusterId" $licenseFile

# connect to cluster
Write-Host "`nConnecting to $vip"
if($mfaCode){
    $mfaCode = Read-Host -Prompt 'Please Re-enter MFA Code'
}
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -noPromptForPassword $noPrompt -quiet
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# upload new license
Write-Host "- Uploading license key"
$result = fileUpload "https://$vip/irisservices/api/v1/nexus/license/upload" $licenseFile
Write-Host "`nCompleted`n"
