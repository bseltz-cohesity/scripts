# Download a File from Cohesity using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell downloads a file from a backup on Cohesity

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/downloadFile/downloadFile.ps1).content | Out-File downloadFile.ps1; (Get-Content downloadFile.ps1) | Set-Content downloadFile.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [downloadFile.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/downloadFile/downloadFile.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./downloadFile.ps1 -vip mycluster -username myusername -domain mydomain.net -objectName myserver -fileName myfile.txt -outPath '/Users/myusername/Downloads'
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -objectName: name of the protected object to download a file from
* -fileName: file to download
* -outPath: folder path to download the file to
