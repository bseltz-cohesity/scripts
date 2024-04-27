# Validate Server Backups using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script validates backups for physical and virtual servers. The script will generate an html report and send it to email recipients. The validation process instructs the cluster to mount the latest backup volume and retrieve a directory listing. If the directory is readable, the backup is considered valid.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'validateServerBackup'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [validateServerBackup.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/validateServerBackup/validateServerBackup.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the script like so:

```powershell
./validateServerBackup.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -objectName w2012b, centos2, /ifs/share3 `
                           -smtpServer 192.168.1.95 `
                           -sendTo myusername@mydomain.net `
                           -sendFrom mycluster@mydomain.net
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -objectName: one or more servers (comma separated) to validate
* -objectList: text file containing list of servers (one per line)
* -smtpServer: SMTP gateway to forward email through
* -smtpPort: SMTP port to use (default is 25)
* -sendTo: email addresses to send report to (comma separated)
* -sendFrom: email address to show in the from field
