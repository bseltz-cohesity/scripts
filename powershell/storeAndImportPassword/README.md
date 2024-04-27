# Store and Import an API Password using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script can store and import an API password.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'storeAndImportPassword'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [storeAndImportPassword.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/storeAndImportPassword/storeAndImportPassword.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To store a password or API Key:

```powershell
./storeAndImportPassword.ps1 -vip mycluster `
                             -username myusername `
                             -domain mydomain.net
```

You will be prompted for the password (or API Key) to store. The output will display a key that will be used later to import the password. The password is stored encrypted and can be decrypted using the key during import.

To import a password:

```powershell
./storeAndImportPassword.ps1 -vip mycluster `
                             -username myusername `
                             -domain mydomain.net `
                             -import `
                             -key somekey
```

To import a password:

```powershell
./storeAndImportPassword.ps1 -vip mycluster `
                             -username myusername `
                             -domain mydomain.net `
                             -import `
                             -key somekey `
                             -useApiKey
```

Use the key generated in step 1. This will decrypt the password and import it into user password storage.

## General Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -password: (optional) will prompt if omitted

## Import Parameters

* -import: perform an import (default mode is to store a password)
* -useApiKey: required when importing an API Key
* -key: key for import
