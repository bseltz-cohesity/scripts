# Generate Protection Runs Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script generates a protection runs report.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'clusterProtectionRuns'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [clusterProtectionRuns.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/clusterProtectionRuns/clusterProtectionRuns.ps1): the main python script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script.

```powershell
./clusterProtectionRuns.ps1 -vip mycluster `
                            -username myuser `
                            -domain mydomain.net
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

* -unit: (optional) display sizes in KiB, MiB, GiB, TiB (default is GiB)
* -days: (optional) days back to look for workloads (default is back to cluster creation)
* -objectType: (optional) filter on specific object type (e.g. kSQL)
* -localOnly: (optional) only include local protection jobs
* -includeLogs: (optional) include log backups
* -fullOnly: (optional) include only full backups
* -outputPath: (optional) path to write output file (default is '.')
* -numRuns: (optional) page size per API call (default is 500)
* -amPmFormat: (optional) output times in 12 hour format with AM/PM notation
