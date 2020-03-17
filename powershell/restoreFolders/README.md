# Restore Folders using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script restores a list of folders (provided in a csv file) from one pyhsical server to another.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/restoreFolders/restoreFolders.ps1).content | Out-File restoreFolders.ps1; (Get-Content restoreFolders.ps1) | Set-Content restoreFolders.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/restoreFolders/restoreFolders.csv).content | Out-File restoreFolders.csv; (Get-Content restoreFolders.csv) | Set-Content restoreFolders.csv
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* restoreFolders.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreFolders.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -csv ./restoreFolders.csv
```

```text
Connected!
Restoring server1.mydomain.net/C/Users/mydomain/documents/stuff to server2.mydomain.net/C/Users/mydomain/documents
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -csv: (optional) csv file containing transfer specs (defaults to ./restoreFolders.csv)

## CSV File

The csv file should be formatted like the following example:

```text
source,folderName,target,targetPath
server1.mydomain.net,/home/myusername,server2.mydomain.net,/home/myusername/restore
server3.mydomain.net,/C/Users/myusername/documents/stuff,server4.mydomain.net,/C/Users/myusername/documents
```
