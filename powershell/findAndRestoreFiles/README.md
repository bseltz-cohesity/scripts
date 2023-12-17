# Find and Restore Files using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script finds and restores files from VM, phyisical server and NAS backups.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'findAndRestoreFiles'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [findAndRestoreFiles.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/findAndRestoreFiles/findAndRestoreFiles.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./findAndRestoreFiles.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobName myjob `
                          -sourceObject myserver.mydomain.net `
                          -startPath /bash `
                          -matchString '/m.*\.sh' `
                          -filesNewerThan '2019-01-01 00:00:00'
```

The resulting list will be saved to `filesToRestore.tsv` which can be opened in Excel and reviewed, massaged, etc. If you want to restore the list of files, you can re-run the command using the `-restorePrevious` option, which will read the file back in and perform the restores, or you can run the command with `-restore` which will immediately restore after gathering the list.

```powershell
./findAndRestoreFiles.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobName myjob `
                          -sourceObject myserver.mydomain.net `
                          -startPath /bash `
                          -matchString '/m.*\.sh' `
                          -filesNewerThan '2019-01-01 00:00:00' `
                          -restore `
                          -restorePath /bash/restoreTest
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

## Search Parameters

* -jobName: name of protection job
* -sourceObject: server that was backed up
* -filesNewerThan: (optional) include files newer than date (e.g. '2019-01-01 00:00:00')
* -filesOlderThan: (optional) include files older than date (e.g. '2019-12-31 23:59:59')
* -startPath: (optional) start listing files at path (default is /)
* -matchString: (optional) include files that match regex string (e.g. '/m.+\.sh')
* -recurse: (optional) search subdirectories for files

## Backup Range Selection Parameters

* -showVersions: (optional) just list available versions and exit
* -backupNewerThan: (optional) show versions starting at date (e.g. '07-10-2020 13:30:00')
* -backupOlderThan: (optional) show versions starting at date (e.g. '07-14-2020 23:59:00')
* -runId: (optional) use snapshot version with specific job run ID
* -fileDate: (optional) use snapshot version at or after date specified (deprecated)

## Restore Parameters

* -restore: (optional) immediately restore after search
* -restorePrevious: (optional) restore using existing output file
* -restoreFileList: (optional) alternate file name to use for restore
* -targetObject: (optional) server/VM/NAS to restore to (defaults to sourceObject)
* -restorePath: (optional) restore to alternate path
* -overwrite: (optional) overwrite existing files
* -maxFilesPerRestore: (optional) default is 500

## Additional VM Restore Parameters

* -restoreMethod: (optional) ExistingAgent, AutoDeploy, or VMTools (default is AutoDeploy)
* -vmUser: (optional) required for AutoDeploy and VMTools restore methods, e.g. mydomain.net\myuser
* -vmPwd: (optional) will be prompted if required and omitted
* -vlan: (optional) vlan ID to use for restore (e.g. 60)
