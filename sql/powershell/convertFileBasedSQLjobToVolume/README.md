# Convert a File-based SQL Protection Job to Volume-based using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script converts a file-based SQL protection job to volume-based.

## Warning

This script will delete an existing protection job, and attempt to create a new job in its place. If the new job creation fails, it's possible to end up with a job unintentionally deleted. To mitigate this, the script will export the old job to a JSON file, to allow the job to be recreated.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'convertFileBasedSQLjobToVolume'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [convertFileBasedSQLjobToVolume.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/convertFileBasedSQLjobToVolume/convertFileBasedSQLjobToVolume.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

```powershell
# example
./convertFileBasedSQLjobToVolume.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -jobname 'My SQL Job'
# end example
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -jobname: name of protection job
