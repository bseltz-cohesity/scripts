# Restore Folder using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script restores a folder from one pyhsical server to another.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreFolder'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* restoreFolder.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreFolder.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -source server1.mydomain.net `
                    -folderName /C/Users/myusername/documents/stuff `
                    -target server2.mydomain.net `
                    -targetPath /C/Users/myuser/documents
```

```text
Connected!
Restoring server1.mydomain.net/C/Users/mydomain/documents/stuff to server2.mydomain.net/C/Users/mydomain/documents
```

## Parameters

* -vip: Cohesity cluster to connect to 
* -username: (optional) Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -useApiKey: (optional) Use API key for authentication
* -source: name of source physical server (e.g. server1.mydomain.net)
* -folderName: path of source folder (e.g. /C/Users/myusername/Documents/Stuff)
* -target: name of target physical server (e.g. server2.mydomain.net)
* -targetPath: path of target folder (e.g. /C/Users/myuser/documents)
