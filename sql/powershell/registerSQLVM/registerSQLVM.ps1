### process commandline arguments
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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][string]$vmList, # text file containing vms (one per line)
    [Parameter()][array]$vm, # one or more vms (comma separated)
    [Parameter()][switch]$useAutoDeployAgent, # use installed agent if omitted
    [Parameter()][string]$vmUser, # windows username for auto deploy
    [Parameter()][string]$vmPwd # windows password for auto deploy
)

# gather list of VMs to register
$servers = @()
if($vmList -and (Test-Path $vmList -PathType Leaf)){
    $servers += Get-Content $vmList | Where-Object {$_ -ne ''}
}elseif($vmList){
    Write-Warning "file $vmList not found!"
    exit 1
}
if($vm){
    $servers += $vm
}
if($servers.Length -eq 0){
    Write-Host "No vms to register"
    exit 1
}

### source the cohesity-api helper code
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

$vms = api get protectionSources/virtualMachines

foreach($vmName in $servers){
    $vmName = [string]$vmName
    $vm = $vms | Where-Object name -eq $vmName | Sort-Object -Unique
    if($vm){
        $vm = $vm[0]
        $registrationParams = @{
            "appEnvVec"           = @(
                3
            );
            "usesPersistentAgent" = $true;
            "ownerEntity"         = @{
                "type"         = 1;
                "vmwareEntity" = $vm.vmWareProtectionSource;
                "id"           = $vm.id;
                "parentId"     = $vm.parentId;
                "displayName"  = $vm.name
            }
        }
        if($useAutoDeployAgent){
            if(! $vmUser){
                $vmUser = Read-Host -Prompt "Enter VM Username"
            }
            if(! $vmPwd){
                $secureString = Read-Host -Prompt "Enter password for VM user ($vmUser)" -AsSecureString
                $vmPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
            }
            $registrationParams['credentials'] = @{"username"= $vmUser; "password"= $vmPwd}
            $registrationParams['usesPersistentAgent'] = $false
        }
        "Registering $vmName as SQL server"
        $null = api post /applicationSourceRegistration $registrationParams

    }else{
        Write-Host "VM $vmName not found" -ForegroundColor Yellow
    }
}