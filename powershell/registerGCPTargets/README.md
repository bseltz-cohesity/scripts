# Register List of GCP Archive Targets

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates GCP archive targets from a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'registerGCPTargets'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [registerGCPTargets.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/registerGCPTargets/registerGCPTargets.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and create a CSV file containing the target information like so:

```text
targetname,bucketname,tiertype
my-target1,gcpbucket1,kGoogleStandard
my-target2,gcpbucket2,kGoogleColdline
my-target3,gcpbucket3,kGoogleNearline
```

Valid tier types are:

* kGoogleStandard
* kGoogleNearline
* kGoogleColdline
* kGoogleRegional
* kGoogleMultiRegional

Also provide the GCP service account's json file, then you can run the script like so;

```powershell
# example
./registerGCPTargets.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -jsonfile my-project-xxxxxx.json `
                         -inputfile ./gcptargets.csv
# end example
```

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: (optional) domain of the Cohesity user (defaults to local)
* -jsonfile: GCP service account JSON file (download from IAM)
* -inputfile: path to CSV file (default is gcptargets.csv)
