# Validate Active Directory Backups using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script validates Active Directory backups. The script will generate an html report and send it to email recipients. The validation process instructs the cluster to mount the latest AD backup to a domain controller and start a new instance (AD recovery instance). A simple AD topology query confirms that the recovery instance is up and operational and the backup is considered valid.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'validateADBackup'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [validateADBackup.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/validateADBackup/validateADBackup.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the script like so:

```powershell
./validateADBackup.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net
                       -domainController mydc.mydomain.net `
                       -adUser mydomain.net\myusername `
                       -smtpServer 192.168.1.95 `
                       -sendTo myusername@mydomain.net `
                       -sendFrom mycluster@mydomain.net
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: cohesity user domain (defaults to local)
* -domainController: AD domain controller to mount to
* -adUser: AD user to use to mount recovery AD instance
* -adPasswd: (optional) AD user password (script will prompt and store if omitted)
* -adPort: (optional) valilable TCP port to use for AD recovery instance (default is 62222)
* -smtpServer: SMTP gateway to forward email through
* -smtpPort: SMTP port to use (default is 25)
* -sendTo: email addresses to send report to (comma separated)
* -sendFrom: email address to show in the from field
