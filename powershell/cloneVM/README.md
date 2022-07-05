# Clone a VM using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones a VM.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneVM'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* cloneVM.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./cloneVM.ps1 -vip mycluster `
              -username myusername `
              -domain mydomain.net `
              -vmName myvm `
              -vCenterName myvcenter.mydomain.net `
              -datacenterName mydatacenter `
              -computeResource vSphereCluster1 `
              -folderName myFolder `
              -networkName 'VM Network' `
              -poweron `
              -prefix clone-
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -vmName: Name of VM to recover
* -prefix: (optional) add a prefix to the VM name during restore
* -vCenterName: (optional)vCenter protection source to recover to
* -datacenterName: (optional) name of vSphere data center to recover to
* -computeResource: (optional) name of vSphere cluster or stand-alone host to recover to
* -folderName: (optional) name of vSphere folder to recover to
* -networkName: (optional) VM Network to attach the VM
* -poweron: (optional) power on the VMs during restore (default is false)
* -detachNetwork: (optional) leave VM network disconnected (default is false)

## Specifying a Compute Resource

If your vSphere environment contains HA clusters (most environments do), then use the name of the HA cluster as the computeResource, for example:

```powershell
-computeResource vSphereCluster1
```

or if your vShere environment contains stand-alone ESX hosts, then use the name of the host as the computeResource:

```powershell
-computeResource EsxHost1
```

## Specifying a Folder

You can specify a folder to restore to using any of the following formats:

* /vCenter.mydomain.net/Datacenters/DataCenter1/vm/MyFolder/MySubFolder
* vCenter.mydomain.net/Datacenters/DataCenter1/vm/MyFolder/MySubFolder
* /MyFolder/MySubFolder
* MyFolder/MySubFolder
