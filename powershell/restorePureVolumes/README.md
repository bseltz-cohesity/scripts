# Restore Pure Volumes from Cohesity using Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script restores Pure Storage volumes from a Cohesity backup.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restorePureVolumes'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restorePureVolumes.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restorePureVolumes/restorePureVolumes.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module ([README](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api))

Place both files in a folder together and run the main script like so:

```powershell
# example
./restorePureVolumes.ps1 -vip mycluster `
                         -username myusername `
                         -pureName mypure `
                         -jobName 'my pure backup' `
                         -volumeName myserver_lun1, myserver_lun2 `
                         -prefix 'restore-' `
                         -suffix '-0410'
# end example
```

By default, the latest backup will be used. If you want to use a previous backup, use -showVersions to list the backups available:

```powershell
# example
./restorePureVolumes.ps1 -vip mycluster `
                         -username myusername `
                         -pureName mypure `
                         -jobName 'my pure backup' `
                         -volumeName myserver_lun1, myserver_lun2 `
                         -prefix 'restore-' `
                         -suffix '-0410' `
                         -showVersions
# end example
```

From the output, find the runId if the backup you want, then use -runId:

```powershell
# example
./restorePureVolumes.ps1 -vip mycluster `
                         -username myusername `
                         -pureName mypure `
                         -jobName 'my pure backup' `
                         -volumeName myserver_lun1, myserver_lun2 `
                         -prefix 'restore-' `
                         -suffix '-0410' `
                         -runId 14799238
# end example
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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: name of Cohesity protection group to restore from
* -pureName: name of registered pure array
* -volumeName: (optional) volume name(s) to recover (comma separated)
* -volumeList: (optional) text file with volume names to recover (one per line)
* -prefix: (optional) prefix to apply to recovered volumes
* -suffix: (optional) suffix to apply to recovered volumes
* -showVersions: (optional) show available versions and exit
* -runId: (optional) specify runId (from showVersions) to use for restore
