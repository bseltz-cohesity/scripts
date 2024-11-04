### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$noPrompt,                     # do not prompt for password
    [Parameter()][string]$tenant,                       # org to impersonate
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][string]$sourceUser,
    [Parameter()][string]$sourcePassword
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

$sources = api get "protectionSources/registrationInfo?includeEntityPermissionInfo=true&environments=kVMware"

$mySource = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $sourceName}
if(! $mySource){
    Write-Host "vCenter $sourceName not registered on this cluster!" -ForegroundColor Yellow
}else{
    $sourceInfo = api get "/backupsources?allUnderHierarchy=true&entityId=$($mySource.rootNode.id)&onlyReturnOneLevel=true"
    $updateParams = @{
        'entity' = $sourceInfo.entityHierarchy.entity;
        'entityInfo' = $sourceInfo.entityHierarchy.registeredEntityInfo.connectorParams;
        'registeredEntityParams' = $sourceInfo.entityHierarchy.registeredEntityInfo.registeredEntityParams
    }

    if($sourceUser){
        $updateParams.entityInfo.credentials.username = $sourceUser
    }
    if(! $sourcePassword){
        $secureString = Read-Host -Prompt "Enter password for $sourceName/$($updateParams.entityInfo.credentials.username)" -AsSecureString
        $sourcePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    }
    setApiProperty -object $updateParams.entityInfo.credentials -name 'password' -value $sourcePassword
    Write-Host "Updating $sourceName..."
    $null = api put "/backupsources/$($mySource.rootNode.id)" $updateParams    
}
