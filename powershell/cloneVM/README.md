# Clone a VM using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones one or more VMware VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneVM'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneVM.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cloneVM/cloneVM.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

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

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -vmName: (optional) one or more names of VMs to clone (comma separated)
* -vmList: (optional) text file of VM names to clone (one per line)
* -viewName: (optional) view to host cloned VM (default is 'cloneVMs')
* -prefix: (optional) add a prefix to the VM name during cloning (default is 'clone-')
* -vCenterName: vCenter to clone to
* -datacenterName: name of vSphere data center to clone to
* -computeResource: name of vSphere cluster or stand-alone host to clone to
* -folderName: name of vSphere folder to clone to
* -networkName: (optional) VM Network to attach the VM
* -poweron: (optional) power on the VMs during cloning (default is false)
* -detachNetwork: (optional) leave VM network disconnected (default is false)
* -showVersions: (optional) show available versions and exit
* -runId: (optional) specify run ID (from show versions) to clone from
* -wait: (optional) wait for completion and report result

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

You can specify a folder to clone to using any of the following formats:

* /vCenter.mydomain.net/Datacenters/DataCenter1/vm/MyFolder/MySubFolder
* vCenter.mydomain.net/Datacenters/DataCenter1/vm/MyFolder/MySubFolder
* /MyFolder/MySubFolder
* MyFolder/MySubFolder
