# Perform Instant Volume Mount using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an Instant Volume Mount using PowerShell.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'instantVolumeMount'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/tearDownVolumeMount.ps1").content | Out-File "tearDownVolumeMount.ps1"; (Get-Content "tearDownVolumeMount.ps1") | Set-Content "tearDownVolumeMount.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [instantVolumeMount.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/instantVolumeMount/instantVolumeMount.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example
.\instantVolumeMount.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net ` 
                         -sourceServer server1.mydomain.net `
                         -targetServer server2.mydomain.net
# end example
```

## Tearing Down Mounts

Take note of the taskId reported in the output of the mount operation. You can use that to later tear down the mount, using the tearDownVolumeMount.ps1 script like so:

```powershell
./tearDownVolumeMount.ps1 -vip mycohesity -username admin -taskId 23404
Connected!
Tearing down mount points...
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

* -sourceServer: name of protected server/VM whose volume(s) to mount
* -targetServer: (optional) name of registered server/VM to mount volume(s) to
* -environment: (optional) filter search by environemt type 'kPhysical', 'kVMware', 'kHyperV'
* -id: (optional) filter search by object id
* -showVersions: (optional) show available run IDs and snapshot dates
* -runId: (optional) specify exact run ID
* -date: (optional) use latest snapshot on or before date (e.g. '2023-10-21 23:00:00')
* -showVolumes: (optional) show available volumes
* -volumes: (optional) one or more volumes to mount (comma separated)
* -wait: (optional) wait and report completion status

## VM Parameters

* -hypervisor: (optional) vCenter, SCVMM, ESXi or HyperV instance to find target VM
* -useExistingAgent: (optional) use existing Cohesity agent (VMware only)
* -vmUsername: (optional) guest username to autodeploy Cohesity agent
* -vmPassword: (optional) guest passwprd to autodeploy Cohesity agent
