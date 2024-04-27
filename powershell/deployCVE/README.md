# Deploy Clustered Cohesity Virtual Edition Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Note: Please use the download commands below to download the script

This PowerShell script deploys a multi-node Cohesity Virtual Edition (VE) cluster on VMware vSphere. After deploying the OVA, the script performs the cluster setup, applies a license key and accepts the end-user license agreement, leaving the new cluster fully built and ready for login.

This script requires the VMware vSphere PowerCLI module for PowerShell.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployCVE/deployCVE.ps1).content | Out-File deployCVE.ps1; (Get-Content deployCVE.ps1) | Set-Content deployCVE.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployCVE/cohesity-deploy-api.ps1).content | Out-File cohesity-deploy-api.ps1; (Get-Content cohesity-deploy-api.ps1) | Set-Content cohesity-deploy-api.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployCVE/example-deployCVE.ps1).content | Out-File example-deployCVE.ps1; (Get-Content example-deployCVE.ps1) | Set-Content example-deployCVE.ps1
# End download commands
```

## Components

* [deployCVE.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployCVE/deployCVE.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. then, run the main script. The below example deploys a three node cluster with each node on a separate esx host and datastore.

```powershell
.\deployCVE.ps1 -ip 10.2.143.48, 10.2.143.49, 10.2.143.50 `
                -vmName BSeltz-CVE1, BSeltz-CVE2, BSeltz-CVE3 `
                -viHost esx1, esx2, esx3 `
                -viDataStore datastore1, datastore2, datastore3 `
                -vip 10.2.143.51, 10.2.143.52, 10.2.143.53 `
                -netmask 255.255.248.0 `
                -gateway 10.2.136.1 `
                -network1 'VM Network' `
                -network2 'VM Network 2' `
                -metadataSize 51 `
                -dataSize 201 `
                -dnsServers 10.2.143.28, 8.8.8.8 `
                -ntpServers pool.ntp.org `
                -clusterName BSeltz-CVE `
                -clusterDomain sa.corp.cohesity.com `
                -encrypt `
                -fips `
                -viServer 10.2.143.29 `
                -ovfPath '.\cohesity-6.1.1d_release-20190507_1eef123c-8tb.ova' `
                -licenseKey 'ABCD-EFGH-IJKL-MNOP' `
                -accept_eula
```

```text
Connecting to vCenter...
Deploying OVA (node 1 of 3)...
Deploying OVA (node 2 of 3)...
Deploying OVA (node 3 of 3)...
Waiting for VMs to boot...
Performing cluster setup...
New clusterId is 4607641115053002
Waiting for cluster setup to complete...
Accepting eula and applying license key...
Cluster Deployment Complete!
```

## Parameters

* -ip: ip address of the nodes (comma separated, at least 3)
* -vmName: virtual machine names (comma separated, at least 3)
* -viHost: vSphere host name or IP (comma separated, at least 3)
* -viDataStore: vSphere datastore name (comma separated, at least 3)
* -vip: VIP addresses (comma separated, at least 3)
* -netmask: subnet mask of the VM
* -gateway: default gateway of the VM
* -network1: primary virtual machine port group to connect vNic to
* -network2: secondary virtual machine port group to connect vNic to
* -metadataSize: size in GB of the metatdata disk
* -dataSize: size in GB of the data disk
* -dnsServers: list of DNS servers, for example: @('172.16.1.253', '172.16.1.252')
* -ntpServers: list of NTP servers, for example: @('pool.ntp.org', 'another.ntp.org')
* -clusterName: Cohesity cluster name
* -clusterDomain: Cohesity cluster domain name
* -encrypt: (optional) enable encryption
* -fips: (optional) enable fips mode encryption
* -viServer: vCenter DNS name or IP
* -ovfPath: path to OVA file
* -licenseKey: Cohesity license key
* -accept_eula: Accept the Cohesity End-user License Agreement

## Note: use the accept_eula parameter only if you agree to the Cohesity End-User License Agreement
