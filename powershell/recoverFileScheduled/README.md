# Recover a File on a Schedule using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script searches for and downloads a file. If run on a schedule it will also delete old versions of the file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoverFileScheduled'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [recoverFileScheduled.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/recoverFileScheduled/recoverFileScheduled.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./recoverFileScheduled.ps1 -vip mycluster -username myusername -d mydomain.net -objectName someVM -fileName someFile -outPath /Users/myusername/Downloads/myfile -keepFor 7
```

```text
Connected!
myfile3
Downloading someFile to /Users/myusername/Downloads/myfile-2019-06-26-09-12-14...
Deleting myfile-2019-06-10-09-06-08...
Deleting myfile-2019-06-11-09-06-23...
```

The output will be written to both the screen as well as a log file: recoverFileScheduledLog.txt in the current directory.

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -objectName: name of the VM or server where the file was backed up from
* -fileName: name of the file to be downloaded
* -outPath: full path and filename that you want the file to be downloaded to
* -keepFor: number of days to keep. Any older versions will be deleted
