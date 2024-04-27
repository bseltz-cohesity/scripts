# License Cluster using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script generates a license and applies it to a cluster

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'licenseCluster'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [licenseCluster.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/licenseCluster/licenseCluster.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./licenseCluster.ps1 -vip mycluster
```

## Cluster Authentication Parameters

* -vip: Cohesity cluster to connect to
* -username: (optional) Cohesity username (defaults to 'admin')
* -domain: (optional) Active Directory domain (defaults to 'local')
* -password: (optional) will use cached password or will be prompted

## Helios Authentication Parameters

* -heliosVip: (optional) defaults to 'helios.cohesity.com'
* -heliosUser: (optional) defaults to 'helios'
* -heliosKey: (optional) API Key for Helios access, will use cached key or will be prompted
