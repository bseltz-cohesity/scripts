# Relicense a Cohesity Cluster using PowerShell

*Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.*

This PowerShell script uploads the license audit report from the cluster to Helios, then downloads and applied the updated license key.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'reLicenseCluster'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* relicenseCluster.ps1: the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
# example
./reLicenseCluster.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net ` 
                       -heliosUser myheliosuser@mydomain.net
# end example
```

## Cluster Authentication Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted if omitted
* -mfaCode: (optional) TOTP MFA code

## Helios Authentication Parameters

* -heliosVip: (optional) name or IP of Helios/MCM endpoint (defaults to 'helios.cohesity.com')
* -heliosUser: (optional) helios username (defaults to 'helios')
* -heliosKey: (optional) API key for Helios access (will use cached key or will be prompted if omitted)

## Acquiring a Helios API Key

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click Settings -> Access Management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key token (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for an API Key/password. Enter the API key as the password.
