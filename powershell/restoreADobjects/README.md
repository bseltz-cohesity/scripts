# Restore Active Directory Objects using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script restores Active Directory objects.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreADobjects'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreADobjects.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restoreADobjects/restoreADobjects.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the script like so:

To restore two objects (msmith and server1) from the latest available backup:

```powershell
./restoreADobjects.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -domainController dc01.mydomain.net `
                       -adUser 'mydomain.net\myuser' `
                       -objectName msmith, server1
```

To list available backup versions:

```powershell
./restoreADobjects.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -domainController dc01.mydomain.net `
                       -showVersions
```

Restore the objects from a specific runId:

```powershell
./restoreADobjects.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -domainController dc01.mydomain.net `
                       -adUser 'mydomain.net\myuser' `
                       -objectName msmith, server1 `
                       -runId 12345
```

You can also use `-objectList myfile.txt` to specify object names, where the text file contains one object name per line.

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: cohesity user domain (defaults to local)
* -domainController: AD domain controller to mount to
* -adUser: (optional) AD user to use to mount recovery AD instance (will be prompted if omitted)
* -adPasswd: (optional) AD user password (will be prompted if omitted)
* -adPort: (optional) valilable TCP port to use for AD recovery instance (default is 9001)
* -objectName: (optional) names of objects to restore (comma separated)
* -objecList: (optional) text file of objects to restore (one per line)
* -runId: (optional) use backup version for restore (default is latest version)
* -showVersions: (optional) show available run IDs and dates
* -ignoreErrors: (optional) don't wait to confirm successful restores
* -reportDifferences: (optional) generate report of object differences (output to CSV)
