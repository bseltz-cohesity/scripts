# Dump Protection Groups to JSON using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script dumps the specified protection groups to JSON for analysis.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'jobDumper'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [jobDumper.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/jobDumper/jobDumper.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

To dump a specific job:

```powershell
# example
./jobDumper.py -vip mycluster `
                    -username myuser `
                    -domain mydomain.net ` 
                    -jobName 'my job'
# end example
```

To dump all jobs of a specific type:

```powershell
# example
./jobDumper.py -vip mycluster `
                    -username myuser `
                    -domain mydomain.net ` 
                    -envirmonment kVMware
# end example
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -tenant: (optional) impersonate a multitenancy org
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: (optional) one or more job names to monitor (comma separated)
* -jobList: (optional) text file of job names to monitor (one per line)
* -environment: (optional) filter on jobs with this environment (e.g. kVMware)
* -includeSources: (optional) also dump related protection sources
