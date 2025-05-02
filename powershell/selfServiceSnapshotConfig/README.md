# Configure Cohesity View Snapshot Self-Service Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script enables/disables Snapshot Self Service on Cohesity views.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'selfServiceSnapshotConfig'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* selfServiceSnapshotConfig.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./selfServiceSnapshotConfig.ps1 -vip mycluster -username myusername -domain mydomain.net -enable
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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Action Paramerterrs

* -enable: (optional) enable snapshot self-service
* -disable: (optional) disable snapshot self-service

## SMB Access Parameters

* -allow: (optional) allow one or more self service principals (e.g. -allow 'MYDOMAIN.NET\Domain Admins', 'MYDOMAIN.NET\Domain Users')
* -deny: (optional) deny one or more self service principals (e.g. -deny 'MYDOMAIN.NET\Print Operators', 'MYDOMAIN.NET\Backup Operators')

## View Selection Parameters

* -viewNames: (optional) one or more view names (comma separated)
* -viewList: (optional) text file of view names (one per line)
* -nfsOnly: (optional) operate on NFS views only
* -smbOnly: (optional) operate on SMB views only

## View Selection

By default, all NFS and SMB views are selected (snapshot self-service is not applicable to S3 views).

You can:

* use the -nfsOnly switch to limit the list to NFS views only
* use the -smbOnly switch to limit the list to SMB views only

or you can select specific views:

* specify one or more views using the -viewNames parameter (e,g, -viewNames view1, view2, view3)
* specify multiple views using a text file with one view name per line
