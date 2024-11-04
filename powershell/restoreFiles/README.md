# Restore Files using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script restores files from physical server backups.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreFiles'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreFiles.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restoreFiles/restoreFiles.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreFiles.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -sourceServer server1.mydomain.net `
                    -targetServer server2.mydomain.net `
                    -fileNames /home/myuser/file1, /home/myuser/file2 `
                    -restorePath /tmp/restoretest1/ `
                    -wait
```

```text
Connected!
Restoring Files...
Restore finished with status Success
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

## Other Parameters

* -sourceServer: server that was backed up
* -targetServer: (optional) server to restore to (defaults to sourceServer)
* -registeredSource: (optional) name of registered source (e.g. name of registered netapp, isilon)
* -registeredTarget: (optional) name of registered target (e.g. name of registered netapp, isilon)
* -jobName: (optional) filter by job name
* -fileNames: (optional) file names to restore (comma separated)
* -fileList: (optional) text file of file names to restore
* -restorePath: (optional) path to restore files on targetServer
* -start: (optional) oldest backup date to restore files from (e.g. '2020-04-18 18:00:00')
* -end: (optional) newest backup date to restore files from (e.g. '2020-04-20 18:00:00')
* -runId: (optional) use specified runId to restore files from
* -latest: (optional) use the latest backup date to restore files from
* -wait: (optional) wait for completion and report status
* -showLog: (optional) show detailed log output after completion
* -overwrite: (optional) overwrite existing files
* -rangeRestore: (optional) restore all versions (of folder) newset to oldest
* -showVersions: (optional) show available versions
* -noIndex: (optional) do not use search index to find files
* -restoreFromArchive: (optional) force restore from archive
* -isilonZoneId: (optional) Isilon zone name of target object
* -taskName: (optional) restore task name

## Backup Versions

By default, the script will search for each file and restore it from the newest version available for that file. You can narrow the date range that will be searched by using the `-start` and `-end` parameters.

Using the `-runId` or `-latest` parameters will cause the script to try to restore all the requested files at once (in one recovery task), from one backup version.

## File Names and Paths

File names must be specified as absolute paths like:

* Linux: /home/myusername/file1
* Windows: c:\Users\MyUserName\Documents\File1 or /C/Users/MyUserName/Documents/File1
