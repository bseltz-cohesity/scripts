
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$esxiHostname,
    [Parameter(Mandatory = $True)][string]$esxiUser,
    [Parameter()][string]$esxiPassword,
    [Parameter(Mandatory = $True)][string]$connectionName,
    [Parameter()][Int64]$minFreeSpaceGiB = 0,
    [Parameter()][Int64]$minFreeSpacePct = 0,
    [Parameter()][Int64]$maxStreams = 0
)

. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if(! $esxiPassword){
    $secureESXiPassword = Read-Host -Prompt "Enter registration password for ESXi" -AsSecureString
    $esxiPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureESXiPassword ))
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

# register ESXi
$esxiParams = @{
    "environment" = "kVMware";
    "connectionId" = $rigelGroup.groupId;
    "vmwareParams" = @{
        "type" = "kStandaloneHost";
        "esxiParams" = @{
            "endpoint" = $esxiHostname;
            "password" = $esxiPassword;
            "username" = $esxiUser;
            "minFreeDatastoreSpaceForBackupGb" = $null;
            "minFreeDatastoreSpaceForBackupPercentage" = $null;
            "maxConcurrentStreams" = $null
        }
    }
}

if($minFreeSpaceGiB -gt 0){
    $esxiParams.vmwareParams.esxiParams.minFreeDatastoreSpaceForBackupGb = $minFreeSpaceGiB
}
if($minFreeSpacePct -gt 0){
    $esxiParams.vmwareParams.esxiParams.minFreeDatastoreSpaceForBackupPercentage = $minFreeSpacePct
}
if($maxStreams -gt 0){
    $esxiParams.vmwareParams.esxiParams.maxConcurrentStreams = $maxStreams
}

Write-Host "Registering ESXi Host"
$response = api post -mcmv2 data-protect/sources/registrations $esxiParams -region $rigelGroup.regionId
$sourceName = $response.name
return $sourceName
