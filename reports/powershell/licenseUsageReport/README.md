# Generate License Usage Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates a report of license usage per protection group/view and also per tenant.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'licenseUsageReport'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [licenseUsageReport.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/reports/powershell/licenseUsageReport/licenseUsageReport.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To report on a single cluster:

```powershell
# example
./licenseUsageReport.ps1 -vip mycluster -username myusername -domain mydomain.net
# end example
```

To report on multiple clusters:

```powershell
# example
./licenseUsageReport.ps1 -vip mycluster1, mycluster2 -username myusername -domain mydomain.net
# end example
```

To connect through Helios and select specific clusters:

```powershell
# example
./licenseUsageReport.ps1 -username myuser@mydomain.net -clusterName mycluster1, mycluster2
# end example
```

To connect through Helios and select all clusters:

```powershell
# example
./licenseUsageReport.ps1 -username myuser@mydomain.net
# end example
```

## Authentication Parameters

* -vip: (optional) one or more names or IPs of Cohesity clusters, comma separated (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM (comma separated)

## Other Parameters

* -unit: (optional): KiB, MiB , GiB, TiB, MB, GB, or TB (default is MiB)
* -pageSize: (optional) number of items per API query (default is 1000)
