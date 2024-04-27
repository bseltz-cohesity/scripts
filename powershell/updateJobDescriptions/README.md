# Update Protection Group Descriptions using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script updates protection group descriptions from a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateJobDescriptions'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [updateJobDescriptions.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/updateJobDescriptions/updateJobDescriptions.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

First, export existing protection group names, descriptions to a CSV file, like so:

```powershell
./updateJobDescriptions.ps1 -vip mycluster `
                            -username myuser `
                            -domain mydomain.net `
                            -csvFile myfile.csv `
                            -export
```

Then edit the CSV file and update any descriptions you wish to change, then you can import the changes (by running the same command without the export parameter):

```powershell
./updateJobDescriptions.ps1 -vip mycluster `
                            -username myuser `
                            -domain mydomain.net `
                            -csvFile myfile.csv
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -tenant: (optional) multi-tenancy organization name
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -csvFile: path to CSV file to import/export
* -export: (optional) export existing names, descriptions to a new CSV
