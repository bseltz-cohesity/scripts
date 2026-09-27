# Restore an M365 OneDrive using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script restores one or more M365 OneDrives.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreM365Onedrive'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreM365Onedrive.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restoreM365Onedrive/restoreM365Onedrive.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./restoreM365Onedrive.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -sourceUserName jsmith@mydomain.net
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster, or Helios endpoint (defaults to helios.cohesity.com)
* -username: name of user to connect to Cohesity cluster (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -tenant: (optional) tenant organization name to impersonate
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mcm: (optional) connect through Helios/MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: name of the registered cluster to access (required when connecting through Helios/MCM)

## Restore Parameters

* -sourceUserName: one or more OneDrive owner names or SMTP addresses to restore (comma separated)
* -sourceUserList: (optional) path to a text file of OneDrive owner names/SMTP addresses, one per line
* -source: (optional) name of the registered M365 source, used to disambiguate OneDrives protected under more than one source
* -recoverDate: (optional) restore from the latest snapshot taken before this date/time (defaults to the most recent snapshot)
* -targetOneDrive: (optional) name or SMTP address of a OneDrive owner to restore into, instead of the original OneDrive
* -targetSource: (optional) name of the registered M365 source that owns -targetOneDrive, if it differs from -source
* -folderPrefix: (optional) top-level folder name to restore into when using -targetOneDrive (defaults to 'restore'; OneDrive contents land in `<folderPrefix>-<sourceUserName>`)
* -continueOnError: (optional) skip OneDrives that can't be found or have no matching snapshot, instead of exiting

## Examples

Restore a single OneDrive in place, from the most recent snapshot:

```powershell
./restoreM365Onedrive.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -sourceUserName jsmith@mydomain.net
```

Restore several OneDrives read from a text file:

```powershell
./restoreM365Onedrive.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -sourceUserList .\onedriveUsers.txt
```

Restore a OneDrive to a point in time, skipping any user with no matching snapshot rather than stopping:

```powershell
./restoreM365Onedrive.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -sourceUserName jsmith@mydomain.net,bwilson@mydomain.net `
                          -recoverDate '2026-09-01 08:00:00' `
                          -continueOnError
```

Restore a OneDrive into a different (alternate) OneDrive, under a named top-level folder:

```powershell
./restoreM365Onedrive.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -sourceUserName jsmith@mydomain.net `
                          -targetOneDrive archive-admin@mydomain.net `
                          -folderPrefix recovered
```

Restore through Helios/MCM to a specific registered cluster:

```powershell
./restoreM365Onedrive.ps1 -vip helios.cohesity.com `
                          -username myusername `
                          -mcm `
                          -clusterName mycluster `
                          
                          -sourceUserName jsmith@mydomain.net
```
