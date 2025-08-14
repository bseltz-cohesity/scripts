# Migrate Views to Another Storage Domain using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script helps migrate views to a new storage domain.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory.

```powershell
# Download Commands
$scriptName = 'migrateView'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [migrateView.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/migrateView/migrateView.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## Examples

First, run the script like so. This will create new, empty views with the specified suffix in the specified storage domain (all other view settings will be migrated), and will also create a protection group matching the source view's protection (if any):

```powershell
./migrateView.ps1 -vip mycluster `
                  -username myuser `
                  -domain mydomain.net `
                  -viewName view1, view2 `
                  -suffix migrate `
                  -newStorageDomainName OtherStorageDomain
```

**Note**: the script does not copy any data. You must mount the source and target views from a host and perform the copy of files.

Once the file copy is complete, we can finalize the migration. This step will rename the old views, and the new views will be renamed to the original view names.

```powershell
./migrateView.ps1 -vip mycluster `
                  -username myuser `
                  -domain mydomain.net `
                  -viewName view1, view2 `
                  -suffix migrate `
                  -finalize
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

* -suffix: temporary suffix for new views
* -viewNames: (optional) one or more view names to process (comma separated)
* -viewList: (optional) text file of view names to process (one per line)
* -newStorageDomainName: (optional) name of storage domain to create the new views
* -finalize: (optional) perform final view renames
* -pageCount: (optional) page size for directory quotas (default is 1000)

## Authenticating to Helios

The Test/Wrapper scripts can be configured to log onto clusters directly, or log onto Helios.

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
