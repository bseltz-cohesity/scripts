# Generate Backup Summary Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script genrates a backup summary report saved to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'backupSummaryReport'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [backupSummaryReport.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/reports/powershell/backupSummaryReport/backupSummaryReport.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./backupSummaryReport.ps1 -vip mycluster -username myusername -domain mydomain
```

## Parameters

* -vip: (optional) DNS or IP of the Cohesity Cluster (default is 'helios.cohesity.com')
* -username: (optional) Cohesity User Name (default is 'helios')
* -domain: (optional) defaults to 'local'
* -useApiKey: (optional) use API key for cluster authentication
* -password: (optional) clear text password (will be prompted if omitted)
* -mcm: (optional) authenticate to MultiCluster Manager
* -mfaCode: (optional) supply TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through helios or MCM
* -unit: (optional) KiB, MiB, GiB or TiB (default is MiB)
* -daysBack: (optional) default is 7
