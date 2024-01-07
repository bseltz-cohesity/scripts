# Generate Estimated Storage Per Object Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates a report of estimated storage consumption per object. Note that this report performs estimation so is not expected to be completely accurate.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'storagePerObjectReport'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [storagePerObjectReport.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/reports/powershell/storagePerObjectReport/storagePerObjectReport.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example
./storagePerObjectReport.ps1 -vip mycluster -username myusername -domain mydomain.net
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

* -numRuns: (optional) number of runs per API query (default is 1000)
* -growthDays: (optional) number of days to measure recent growth (default is 7)
* -skipDeleted: (optional) skip deleted protection groups
* -unit: (optional) MiB or GiB (default is GiB)

## Column Descriptions

* Job Name: name of protection group
* Tenant: name of organization
* Environment: protection group type
* Source Name: name of registered source (e.g. vCenter, server, etc.)
* Object Name: name of object (e.g. VM, NAS share, database, etc.)
* Logical GiB: front-end size of object as reported by the source
* GiB Written: amount of deduped/compressed data, for this object, resident on Cohesity (before adding resiliency striping overhead)
* GiB Written plus Resiliency: amount of deduped/compressed data, for this object, resident on Cohesity (after adding resiliency striping overhead)
* Job Reduction Ratio: dedup/compression ratio of protection group
* GiB Written Last 7 Days: amount of deduped/compressed data added, for this object, in past X days
* GiB Archived: amount of deduped/compressed data, for this object, resident on cloud archive targets
* GiB per Archive Target: amount of deduped/compressed data, for this object, resident on each archive target
