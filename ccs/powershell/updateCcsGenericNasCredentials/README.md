# Update CCS Generic NAS Credentials using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script updates the SMB credentials of registered Generic NAS (kGenericNas) protection sources in CCS.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateCcsGenericNasCredentials'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [updateCcsGenericNasCredentials.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/updateCcsGenericNasCredentials/updateCcsGenericNasCredentials.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To see the list of Generic NAS sources:

```powershell
./updateCcsGenericNasCredentials.ps1
```

To filter by mount mode:

```powershell
./updateCcsGenericNasCredentials.ps1 -mode kCifs1
```

To filter by name:

```powershell
./updateCcsGenericNasCredentials.ps1 -sourceName '\\nas1\share1', '\\nas1\share2'
```

To filter by region:

```powershell
./updateCcsGenericNasCredentials.ps1 -region us-east-2
```

To update credentials:

```powershell
./updateCcsGenericNasCredentials.ps1 -sourceName '\\nas1\share1', '\\nas1\share2' `
                                     -update `
                                     -smbUser 'mydomain.net\myuser'
```

## Basic Parameters

* -username: (optional) username to authenticate to Helios (default is 'ccs')
* -password: (optional) API key to authenticate to Helios (will be prompted if omitted)

## Filter Parameters

* -sourceName: (optional) filter by registered source names (comma separated)
* -sourceList: (optional) text file of registered source names to filter by (one per line)
* -region: (optional) filter by a single CCS region id (e.g. us-east-2)
* -mode: (optional) filter by mount mode (kNfs3, kNfs4_1 or kCifs1)

## Update Parameters

* -update: (optional) perform credential update
* -smbUser: (optional) SMB username for credential update (will be prompted if omitted)
* -smbPassword: (optional) SMB password for credential update (will be prompted if omitted)

## Notes

* The source list (and `genericnas-sources.csv`) includes the mount point, region, mode and current SMB user of each source.

* If no `-sourceName` or `-sourceList` is specified and `-smbUser` is specified, the script operates on all sources that currently use that SMB user (so you can update a password across every source using the same account). With `-smbUser` and no names, list mode shows only those sources.
* If `-update` is used with `-smbUser` and no source names, the existing username is kept and only the password changes.
* If source names are specified, those sources are updated to the given `-smbUser` regardless of their current user.

* Credentials apply only to SMB (kCifs1) sources. NFS sources are skipped during update.
* The existing mount point, mode, description and throttling settings are preserved during update.
