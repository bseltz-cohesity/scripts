# Protect O365 Public Folders Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds Public Folders to an O365 protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'protectO365PublicFolders'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [protectO365PublicFolders.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectO365PublicFolders/protectO365PublicFolders.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. You can provide a list of folders at the command line, or create a text file and populate with the folder names or web URLs (one per line), or you can automatically protect unprotected folders.

Then, run the main script like so:

To protect specific folders:

```powershell
# example
./protectO365PublicFolders.ps1 -vip mycluster `
                               -username myusername `
                               -domain mydomain.net `
                               -jobName 'My Job' `
                               -folder my-folder1, my-folder2
# end example
```

To protect a list of folders from a text file:

```powershell
# example
./protectO365PublicFolders.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -jobName 'My Job' `
                       -folderList ./myfolders.txt
# end example
```

To protect automatically selected folders that are unprotected:

```powershell
# example
./protectO365PublicFolders.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -jobName 'My Job' `
                       -allFolders
# end example
```

To create an autoprotect job that excludes folders that are already protected:

```powershell
# example
./protectO365PublicFolders.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -jobName 'My Job' `
                       -autoProtectRemaining
# end example
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: name of the O365 protection job to exclude mailboxes from
* -folder: (optional) a comma separated list of folder names to protect
* -folderList: (optional) a text file list of folder names to protect
* -allFolders: (optional) protect unprotected folders (up to the maxFoldersPerJob)
* -maxFoldersPerJob: (optional) default is 5000
* -sourceName: (optional) name of registered O365 protection source (required for new job)
* -autoProtectRemaining: (optional) autoprotect at the source and exclude already protected folders

## New Job Parameters

* -policyName: (optional) name of the protection policy to use (required for a new protection job)
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/Los_Angeles' (default is 'America/New_York')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -disableIndexing: (optional) disable indexing (indexing is enabled by default)

## Notes

If you have more than 5000 public folders to protect, please read: [Protecting O365 Objects](https://github.com/cohesity/community-automation-samples/blob/main/doc/Protecting%20O365%20Objects.md) for guidance on how to protect O365 objects at scale.
