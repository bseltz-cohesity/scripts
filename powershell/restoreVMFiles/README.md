# Restore VM Files using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script restores files from a VMware VM backup.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreVMFiles'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreVMFiles.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restoreVMFiles/restoreVMFiles.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreVMFiles.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -sourceVM vm1 `
                     -targetVM vm2 `
                     -fileNames /home/myuser/file1, /home/myuser/file2 `
                     -restorePath /tmp/restoretest1/ `
                     -wait
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

* -sourceVM: VM that was backed up
* -targetVM: (optional) VM to restore to (defaults to sourceVM)
* -fileNames: (optional) file /path/names to restore (comma separated)
* -fileList: (optional) text file of file path/names to restore (one per line)
* -restorePath: (optional) path to restore files on targetServer
* -restoreMethod: (optional) ExistingAgent, AutoDeploy, or VMTools (default is AutoDeploy)
* -vmUser: (optional) required for AutoDeploy and VMTools restore methods, e.g. mydomain.net\myuser
* -vmPwd: (optional) will be prompted if required and omitted
* -showVersions: (optional) show available backups (run ID and run date) and exit
* -olderThan: (optional) restore from last version prior to this date, e.g. '2021-01-31', '2021-01-30 23:00'
* -daysAgo: (optional) restore from last backup X days ago (1 = last night, 2 = night before last)
* -runId: (optional) restore specified runId
* -wait: (optional) wait for completion and report status
* -noIndex: (optional) use if VM is not indexed, file paths must be exact case
* -localOnly: (optional) restore from local snapshots only
* -overwrite: (optional) overwrite existing files
* -taskString: (optional) custom string in recovery task name (default is RestoreFiles_sourcevm_date)
* -vlan: (optional) vlan ID to use for restore (e.g. 60)
* -jobName: (optional) filter by protection group name

## File Names and Paths

File names must be specified as absolute paths, like:

* Linux: /home/myusername/file1
* Windows: c:\Users\MyUserName\Documents\File1 or /C/Users/MyUserName/Documents/File1

## Selecting a Point in Time

By default, the latest backup will be used. You can use one of the following to select a different point in time:

-showVersions: this switch will display the backup run dates and IDs that are available to select. Once you find the date you are looking for, you can specify that run ID using the -runId parameter.

-runId: specify a runId (use -showVersions to see the list of available runIds).

-olderThan: specify a date in formats like 'YYYY-MM-DD HH:mm:ss' e.g. '2021-01-31', '2021-01-30 23:00', '2021-01-30 23:01:45'. The script will select the latest point in time before the specified date.

-daysAgo: the script will select the latest point in time that is X days ago. Yesterday is 1 day ago, so -daysAgo 1 will select the last backup that ran yesterday. -daysAgo 2 will select the last backup that occurred the day before yesterday, and so on.
