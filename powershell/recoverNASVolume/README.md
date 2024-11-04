# Recover a NAS Volume using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script recovers a NAS volume.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoverNASVolume'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [recoverNASVolume.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/recoverNASVolume/recoverNASVolume.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the script like so:

To restore a volume:

```powershell
./recoverNASVolume.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -sourceVolume /ifs/share1
```

To restore to an alternate location:

```powershell
./recoverNASVolume.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -sourceVolume /ifs/share1 `
                       -targetVolume \\myserver\myshare
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

* -sourceVolume: name of source volume to restore from
* -sourceName: (optional) name of registered source to restore from
* -targetVolume: (optional) name of target volume to restore to
* -targetName: (optional) name of registered source to restore to
* -overwrite: (optional) overwrite existing files
* -wait: (optional) wait for completion and report outcome
* -sleepTime: (optional) seconds to wait between status queries (default is 30)

## Version Selection

* -showVersions: (optional) show available backups
* -runId: (optional) specify runId (see output of -showVersions)
