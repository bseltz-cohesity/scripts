# Clone a VMware VM to Azure using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones a VMware VM to Azure.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneVmToAzure'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneVmToAzure.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cloneVmToAzure/cloneVmToAzure.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./cloneVmToAzure.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -vmName myvm `
                     -prefix 'restore' `
                     -powerOn `
                     -azureSource 0f2537ad-bf52-2711-ac6e-b2f5d2bc737c `
                     -resourceGroup rg1cloudazure66 `
                     -storageAccount sa1cloudazure66 `
                     -storageContainer sc1cloudazure66 `
                     -virtualNetwork vnet1cloudazure66-vnet `
                     -subnet default `
                     -instanceType Standard_A1 `
                     -recoverDate '2023-04-29 16:11' `
                     -wait
```

## Authentication Parameters

* -vip: (optional) cluster to connect to (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -clusterName: (optional) cluster to connect to when connect to when connecting through Helios
* -mfaCode: (optional) OTP code for MFA

## Other Parameters

* -vmName: Name of VM to recover
* -recoverDate: (optional) e.g. '2021-08-18 23:30:00' (will use most recent at or before this date)
* -prefix: (optional) add a prefix to the VM name during restore
* -suffix: (optional) add a suffix to the VM name during restore
* -poweron: (optional) power on the VMs during restore (default is false)
* -azureSource: Azure protection source to restore to
* -instanceType: compute option to use
* -resourceGroup: resource group to restor to
* -storageResourceGroup: (optional) defaults to same as resource group
* -storageAccount: storage account to restore to
* -storageContainer: storage container to restore to
* -vnetResourceGroup: (optional) defaults to same as resource group
* -virtualNetwork: VNet to connect the VM to
* -subnet: Subnet to connect to
* -useManagedDisks: (optional) use Azure managed disks
* -osDiskType: (optional) kStandardSSD, kPremiumSSD or kStandardHDD (default is kStandardSSD)
* -dataDiskType: (optional) kStandardSSD, kPremiumSSD or kStandardHDD (default is kStandardSSD)
* -wait: (optional) wait for completion and return new instance IP address
