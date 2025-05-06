# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$sourceCluster,
    [Parameter(Mandatory = $True)][string]$sourceUser,
    [Parameter()][string]$sourceDomain = 'local',
    [Parameter(Mandatory = $True)][string]$targetCluster,
    [Parameter()][string]$targetUser = $sourceUser,
    [Parameter()][string]$targetDomain = $sourceDomain,
    [Parameter()][switch]$useApiKeys,
    [Parameter()][switch]$clearExistingRules,
    [Parameter()][switch]$promptForMfaCode
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$cacheFile = "$($sourceCluster)-Rules.json"
if(Test-Path -Path $cacheFile -PathType Leaf){
    "`nUsing cached rules from source cluster $sourceCluster..."
    $rules = Get-Content -Path $cacheFile | ConvertFrom-Json
}else{
    "`nConnecting to source cluster $sourceCluster..."
    $mfaCode = $null
    if($promptForMfaCode){
        $mfaCode = Read-Host -Prompt 'Please Enter MFA Code'
    }
    apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -apiKeyAuthentication $useApiKeys -mfaCode $mfaCode -quiet

    # get certs
    Write-Host "Getting Alert Notification Rules..."
    $rules = api get alertNotificationRules
    $rules | toJson | Out-File -FilePath $cacheFile
}

"`nConnecting to target cluster $targetCluster..."
$mfaCode = $null
if($promptForMfaCode){
    $mfaCode = Read-Host -Prompt 'Please Enter MFA Code'
}
apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -apiKeyAuthentication $useApiKeys -mfaCode $mfaCode -quiet

$cacheFile = "$($targetCluster)-Rules.json"

# backup original certs
$origRules = api get alertNotificationRules
if(! (Test-Path -Path $cacheFile -PathType Leaf)){
    $origRules | toJson | Out-File -FilePath $cacheFile
}

if($clearExistingRules){
    Write-Host "Clearing Existing Rules..."
    foreach($rule in $origRules){
        $null = api delete alertNotificationRules/$($rule.ruleId)
    }
}

# copy new certs
Write-Host "Copying Alert Notification Rules..."
foreach($rule in $rules){
    $null = api post alertNotificationRules $rule
}
