# Deploy Helios Self-MAnaged Virtual Edition using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script deploys Helios Self-Managed OVAs to VMware and builds a Helios cluster.

## Requirements

This script requires vSphere PowerCLI to deploy, configure and power on VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'deployHSM'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [deployHSM.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployHSM/deployHSM.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
.\deployHSM.ps1 -ip 10.1.0.100, 10.1.0.101, 10.1.0.102, 10.1.0.103 `
                -vmName helios1, helios2, helios3, helios4 `
                -viServer vcenter.mydomain.net `
                -viHost esx1, esx2, esx3, esx4 `
                -viDataStore datastore1, datastore2, datastore3, datastore4 `
                -ovfPath 'e:\cohesity-onehelios-esx-1.3.0_heliossm_release-20251211_676961dc.ova' `
                -netmask 255.255.255.0 `
                -gateway 10.1.0.1 `
                -network1 'DSwitch-VM Network' `
                -network2 'DSwitch-VM Network' `
                -deployOVA `
                -buildCluster `
                -restore `
                -vip 10.1.0.105 `
                -dnsServers @('10.1.0.45','10.1.0.46') `
                -ntpServers @('10.1.0.47','10.1.0.48') `
                -clusterName helios `
                -clusterDomain mydomain.net `
                -appSubnet 192.168.0.0 `
                -appNetmask 255.255.240.0 `
                -accessKey fake_12ikDe-LK2IYaxHfakeWCBRzbPcO3AAhafiAWg `
                -secretKey fake_iTu2VniXYfaJ_cafakeIe3VQESP4JwtAKXKrd5 `
                -s3Host 'https://cluster1.mydomain.net:3000' `
                -s3Bucket heliosbk `
                -restorePrefix 'helios/019ceff9-0704-7b42-b317-52bbe49b8016'
```

## Step Parameters

* -deployOVA: run the deploy OVA section of the script
* -buildCluster: run the build cluster section of the script
* -restore: run the restore section of the script (in conjunction with -buildCluster)

## vSphere Parameters

* -viServer: vCenter DNS name or IP
* -vmName: virtual machine names (comma separated, at least 4)
* -viHost: vSphere host name or IP (comma separated, at least 4)
* -viDataStore: vSphere datastore name (comma separated, at least 4)
* -ovfPath: path to OVA file

## Helios Cluster Parameters

* -ip: ip address of the nodes (comma separated, at least 4)
* -vip: VIP address for the Helios cluster
* -netmask: subnet mask of the nodes and cluster
* -gateway: default gateway of nodes andd cluster
* -appSubnet: subnet for apps
* -appNetmask: subnet mask fpr apps subnet
* -network1: primary virtual machine port group to connect vNic to
* -network2: secondary virtual machine port group to connect vNic to
* -metadataSize: size in GB of the metatdata disk
* -dataSize: size in GB of the data disk
* -dnsServers: list of DNS servers, for example: @('172.16.1.253', '172.16.1.252')
* -ntpServers: list of NTP servers, for example: @('pool.ntp.org', 'another.ntp.org')
* -clusterName: Helios cluster name
* -clusterDomain: Helios cluster domain name

## Restore Parameters

* -accessKey: s3 access key for access to restore repository
* -secretKey: s3 secret key for access to restore repository
* -s3Host: s3 host for access to restore repository
* -s3Bucket: s3 bucket for access to restore repository
* -restorePrefix: folder in restore repository to restore from
