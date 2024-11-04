# Restore One Drive Files Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script restores OneDrive files.

`Note`: this script is a minimum viable prototype. Additional features may be added in the future but it currently has the following limitations:

* OneDrive backups must be indexed (the script uses search, not browse)
* Only restores latest version of each requested file/folder
* Performs one recovery task per requested file/folder
* -targetUser must also be protected

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreOneDriveFiles'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreOneDriveFiles.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restoreOneDriveFiles/restoreOneDriveFiles.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreOneDriveFiles.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -sourceUser someuser@mydomain.onmicrosoft.com `
                           -fileName /Folder-01/File-01.txt, /Folder-01/File-02.txt
```

To restore a long list of files, create a text file (e.g. files.txt) with one path per line, then:

```powershell
./restoreOneDriveFiles.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -sourceUser someuser@mydomain.onmicrosoft.com `
                           -fileList ./files.txt
```

To restore to an altername user's OneDrive:

```powershell
./restoreOneDriveFiles.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -sourceUser someuser@mydomain.onmicrosoft.com `
                           -targetUser anotheruser@mydomain.onmicrosoft.com `
                           -fileList ./files.txt
```

To restore to an alternate folder:

```powershell
./restoreOneDriveFiles.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -sourceUser someuser@mydomain.onmicrosoft.com `
                           -targetFolder /tmp `
                           -fileList ./files.txt
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

* -sourceUser: OneDrive user to restore from/to
* -targetUser: (optional) OneDrive user to restore to
* -fileName: (optional) one or more file paths (comma separated) to restore e.g. /Folder-01/File-01.txt
* -fileList: (optional) text file of file paths to restore (one per line)
* -targetFolder: (optional) path to restore files e.g. /tmp
* -localOnly: (optional) only restore files if a local snapshot exists
* -archiveOnly: (optional) only restore files if an archive snapshot exists
