# Deploy Cohesity Virtual Edition Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Note: Please use the download commands below to download the script

This PowerShell script deploys a single-node Cohesity Virtual Edition (VE) appliance on VMware vSphere. After deploying the OVA, the script performs the cluster setup, applies a license key and accepts the end-user license agreement, leaving the new cluster fully built and ready for login.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'deployVE'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [deployVE.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployVE/deployVE.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
.\deployVE.ps1 -ip 172.16.1.194 `
               -netmask 255.255.255.0 `
               -gateway 172.16.1.1 `
               -vmNetwork 'VM Network' `
               -vmName VE2 `
               -metadataSize 51 `
               -dataSize 201 `
               -dnsServers @('172.16.1.253', '172.16.1.252') `
               -ntpServers @('pool.ntp.org') `
               -clusterName CohesityVE2 `
               -clusterDomain mydomain.net `
               -viServer 172.16.1.202 `
               -viHost 172.16.1.200 `
               -viDataStore nvme `
               -ovfPath 'c:\save\cohesity-6.1.1d_release-20190315_3d1332e6.ova' `
               -licenseKey 'XXXX-XXXX-XXXX-XXXX'
```

```text
Connecting to vCenter...
Setting OVA configuration...
Deploying OVA...
Adding data disks to VM...
Powering on VM...
Waiting for VM to boot...
Performing cluster setup...
Waiting for cluster setup to complete...
Accepting eula and applying license key...
VE Deployment Complete
```

## Parameters

* -ip: ip address of the VM
* -netmask: subnet mask of the VM
* -gateway: default gateway of the VM
* -vmNetwork: virtual machine port group to connect vNic to
* -vmName: virtual machine name
* -metadataSize: size in GB of the metatdata disk
* -dataSize: size in GB of the data disk
* -dnsServers: list of DNS servers, for example: @('172.16.1.253', '172.16.1.252')
* -ntpServers: list of NTP servers, for example: @('pool.ntp.org', 'another.ntp.org')
* -clusterName: Cohesity cluster name
* -clusterDomain: Cohesity cluster domain name
* -viServer: vCenter DNS name or IP
* -viHost: vSphere host name or IP
* -viDataStore: vSphere datastore name
* -ovfPath: path to OVA file
* -licenseKey: Cohesity license key
