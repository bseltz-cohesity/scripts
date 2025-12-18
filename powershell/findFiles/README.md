# Search for Files using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script searches for files with the specified file extension

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'findFiles'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [findFiles.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/findFiles/findFiles.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./findFiles.ps1 -vip mycluster -username myusername -domain mydomain.net -searchString ".*myfile.*" -extensionOnly
```

or find all files with the extention .gif:

```powershell
./findFiles.ps1 -vip mycluster -username myusername -domain mydomain.net -searchString ".*gif" -extensionOnly
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
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -searchString: (optional) one or more strings to search for (comma separated)
* -jobName: (optional) filter results by jobName
* -objectName: (optional) filter results by objectName
* -objectType: (optional) filter results by objectType (e.g. kVMware)
* -getMtime: (optional) get last modified date of each file
* -extensionOnly: (optional) only return results where the searchString is the file extension
* -localOnly: (optional) only show rsults from local jobs
* -throttle: (optional) pause for X seconds between paged results
* -pageSize: (optional) 1000 or less (default is 1000)
