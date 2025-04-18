# Recover a Windows Share as a Cohesity View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script recovers a Windows Share (Generic NAS Backup) as a Cohesity View. It can also migrate the SMB Share permissions and child shares from the Windows host.

## Note

If the `-migrateSMBPermissions` or `-migrateChildShares` options are used, then this script **MUST** be run from the Windows server that we are migrating from (otherwise it can be run from anywhere).

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoverWindowsShareAsView'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [recoverWindowsShareAsView.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/recoverWindowsShareAsView/recoverWindowsShareAsView.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the script like so:

To restore a share:

```powershell
./recoverWindowsShareAsView.ps1 -vip mycluster `
                                -username myusername `
                                -domain mydomain.net `
                                -sourceName '\\windows1.mydomain.net\share1' `
                                -migrateSMBPermissions `
                                -migrateChildShares
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Basic Parameters

* -sourceName: name of protected Windows share (e.g. '\\windows1.mydomain.net\share1')
* -viewName: (optional) name of view to create (source share name is used by default)
* -migrateSMBPermissions: (optional) migrate SMB permissions from Windows to View
* -migrateChildShares: (optional) migrate child shares from Windows to View
* -sleepTime: (optional) seconds to wait between status queries (default is 5)

## Backup Version Selection

* -showVersions: (optional) show available backups
* -runId: (optional) specify runId (see output of -showVersions)

## Subnet Allow List Parameters

* -ips: (optional) cidrs to add, examples: 192.168.1.3/32, 192.168.2.0/24 (comma separated)
* -ipList: (optional) text file of cidrs to add (one per line)
* -ipsReadOnly: (optional) readWrite if omitted
* -rootSquash: (optional) enable root squash
* -allSquash: (optional) enable all squash

## Share Permissions

* -fullControl: (optional) list of users to grant full control share permissions (comma separated)
* -readWrite: (optional) list of users to grant read/write share permissions (comma separated)
* -readOnly: (optional) list of users to grant read-only share permissions (comma separated)
* -modify: (optional) list of users to grant modify share permissions (comma separated)
* -superUser: (optional) list of users to grant super user access permissions (comma separated)
