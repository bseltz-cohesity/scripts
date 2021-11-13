### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, # Cohesity username
    [Parameter()][string]$domain = 'local', # Cohesity user domain name
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

### authenticate
apiauth -vip $vip -username $username -domain $domain -quiet

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