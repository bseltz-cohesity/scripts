
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$vCenterName,
    [Parameter(Mandatory = $True)][string]$vCenterUser,
    [Parameter()][string]$vCenterPassword,
    [Parameter(Mandatory = $True)][string]$connectionName,
    [Parameter()][Int64]$minFreeSpaceGiB = 0,
    [Parameter()][Int64]$minFreeSpacePct = 0,
    [Parameter()][Int64]$maxStreamsPerDatastore = 0,
    [Parameter()][Int64]$maxConcurrentBackups = 0,
    [Parameter()][switch]$updateLastBackupDetails
)

. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if(! $vCenterPassword){
    $secureVCenterPassword = Read-Host -Prompt "Enter registration password for vCenter" -AsSecureString
    $vCenterPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureVCenterPassword ))
}

# authenticate to CCS =======================================
Write-Host "Connecting to Cohesity Cloud..."
apiauth -username $username -passwd $password
# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
$userInfo = api get /mcm/userInfo
$tenantId = $userInfo.user.profiles[0].tenantId
# ===========================================================

# wait for SaaS Connection to Connect =======================
$reportWaiting = $True
$connectionStatus = 'disconnected'
while($connectionStatus -ne 'Connected'){
    $rigelGroups = api get -mcmv2 "rigelmgmt/rigel-groups?tenantId=$tenantId&fetchConnectorGroups=true"
    $rigelGroup = $rigelGroups.rigelGroups | Where-Object {$_.groupName -eq $connectionName}
    if(! $rigelGroup){
        Write-Host "SaaS Connection $connectionName not found" -ForegroundColor Yellow
        exit
    }
    $connectionStatus = $rigelGroup.status
    if($connectionStatus -ne 'Connected'){
        if($reportWaiting -eq $True){
            Write-Host "Waiting for SaaS Connection to to Connect..."
            $reportWaiting = $false
        }
        Start-Sleep 15
    }
}
# ===========================================================

# register vCenter
$vCenterParams = @{
    "environment" = "kVMware";
    "connectionId" = $rigelGroup.groupId;
    "vmwareParams" = @{
        "type" = "kVCenter";
        "vCenterParams" = @{
            "endpoint" = $vCenterName;
            "password" = $vCenterPassword;
            "username" = $vCenterUser;
            "minFreeDatastoreSpaceForBackupGb" = $null;
            "minFreeDatastoreSpaceForBackupPercentage" = $null;
            "throttlingParams" = @{
                "maxConcurrentBackups" = $null;
                "maxConcurrentStreams" = $null
            };
            "updateLastBackupDetails" = $null
        }
    }
}

if($minFreeSpaceGiB -gt 0){
    $vCenterParams.vmwareParams.vCenterParams.minFreeDatastoreSpaceForBackupGb = $minFreeSpaceGiB
}
if($minFreeSpacePct -gt 0){
    $vCenterParams.vmwareParams.vCenterParams.minFreeDatastoreSpaceForBackupPercentage = $minFreeSpacePct
}
if($maxStreamsPerDatastore -gt 0){
    $vCenterParams.vmwareParams.vCenterParams.throttlingParams.maxConcurrentStreams = $maxStreamsPerDatastore
}
if($maxConcurrentBackups -gt 0){
    $vCenterParams.vmwareParams.vCenterParams.throttlingParams.maxConcurrentBackups = $maxConcurrentBackups
}
if($updateLastBackupDetails){
    $vCenterParams.vmwareParams.vCenterParams.updateLastBackupDetails = $True
}

Write-Host "Registering vCenter"
$response = api post -mcmv2 data-protect/sources/registrations $vCenterParams -region $rigelGroup.regionId
