# List Runs with Legal Holds using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script lists protection runs where legal holds are present. Output is saved to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'legalHoldList'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* legalHoldList.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./legalHoldList.ps1 -vip mycluster -username myusername -domain mydomain
```

## Parameters

* -vip: DNS or IP of the Cohesity Cluster
* -username: Cohesity User Name
* -domain: (optional) defaults to 'local'
* -jobname: (optional) one or more jobs to search (comma separated)
* -backupType: (optional) limit search to specific run type (kRegular, kFull, kLog, kSystem, kAll)
* -numRuns: (optional) number of runs to request at a time (default is 1000)
