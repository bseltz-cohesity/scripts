# Generate a VM Recovery Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script script creates a VM Recovery report.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'vmRecoveryReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [vmRecoveryReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/vmRecoveryReport/vmRecoveryReport.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example
./vmRecoveryReport.ps1 -vip mycluster -username myusername -domain mydomain.net
# end example
```

To connect through Helios:

```powershell
# example
./vmRecoveryReport.ps1 -username myuser@mydomain.net -clusterName mycluster
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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM (comma separated)

## Other Parameters

* -daysBack: (optional) default is 7
* -taskName: (optional) one or more task names to include (comma separated)
* -taskList: (optional) text file of task names to include (one per line)
* -outfileName: (optional) specify name for output csv file (default is vmRecoveryReport.csv)
