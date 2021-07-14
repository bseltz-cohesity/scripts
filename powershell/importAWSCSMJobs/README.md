# Import and Export Cohesity Objects Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script exports various Cohesity objects to json files, to serve as documentation of cluster state and provide the possibility of re-importing some settings and objects for cluster rebuild or disaster recovery use cases.

Note that re-importing objects is non-trivial and requires complex logic for each object type that depends on the use case and the specific situation. Included here are scripts for re-importing storageDomains, protectionPolciies, Generic NAS sources and Generic NAS protection jobs. More to come on an as needed basis.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'importAWSCSMJobs'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/exportAWSCSMJobs.ps1").content | Out-File exportAWSCSMJobs.ps1; (Get-Content exportAWSCSMJobs.ps1) | Set-Content exportAWSCSMJobs.ps1
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* importAWSCSMJobs.ps1
* exportAWSCSMJobs.ps1
* cohesity-api.ps1: the Cohesity REST API helper module

## Exporting Jobs

Place all files in a folder together. You can run the exportAWSCSMJobs.ps1 script like so:

```powershell
./$scriptName.ps1 -vip myoldcluster `
                  -username myusername `
                  -domain mydomain.net
```

## Importing Jobs

You can run the importAWSCSMJobs.ps1 script like so:

```powershell
./$scriptName.ps1 -vip mynewcluster `
                  -username myusername `
                  -domain mydomain.net `
                  -policyName 'bronze'
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -configFolder: (optional) Defaults to .\configExports

## Additional Parameters for Import Only

* -policyName: name of protection policy to apply to imported jobs
* -storageDomain: (optional) name of storage domain for jobs (default is DefaultStorageDomain)
* -jobNames: (optional) one or more job names (comma separated) to import (default is all jobs) 
