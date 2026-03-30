# File Search for PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script searches for a file and displays the results.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'fileSearch'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* fileSearch.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./fileSearch.ps1 -vip mycluster `
                 -username myusername `
                 -domain mydomain.net `
                 -sourceServer myserver.mydomain.net `
                 -jobName 'my job' `
                 -filePath /home/myuser/myfolder/myfile.txt
```

The script will return a numbered list of search results. To see the avaiable versions of a specific result, use the -showVersions parameter with the result number:

```powershell
./fileSearch.ps1 -vip mycluster `
                 -username myusername `
                 -domain mydomain.net `
                 -sourceServer myserver.mydomain.net `
                 -jobName 'my job' `
                 -filePath /home/myuser/myfolder/myfile.txt `
                 -showVersions 1
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: (optional) name of protection group to modify
* -jobType: (optional) type of protection group (e.g. kVMware, kPhysical)
* -sourceServer: (optional) name of protected object
* -showVersions: (optional) show available versions for a specific result (e.g. -showVersions 1)
* -runId: limit (optional) results to specific run ID
