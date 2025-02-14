# Set Maintenance Mode on Protection Sources using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script starts or ends maintenance mode on protection sources.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'maintenance'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [maintenance.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/maintenance/maintenance.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

Start maintenance now:

```powershell
./maintenance.ps1 -vip mycluster `
                  -username myusername `
                  -domain mydomain.net `
                  -sourceName mysource.mydomain.net ` 
                  -startNow
```

Start maintenance in the future:

```powershell
./maintenance.ps1 -vip mycluster `
                  -username myusername `
                  -domain mydomain.net `
                  -sourceName mysource.mydomain.net ` 
                  -startTime '2025-02-14 17:00:00' `
                  -edTime '2025-02-15 06:00:00'
```

End maintenance now:

```powershell
./maintenance.ps1 -vip mycluster `
                  -username myusername `
                  -domain mydomain.net `
                  -sourceName mysource.mydomain.net ` 
                  -endNow
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

* -sourceName: (optional) one or more source names to manage (comma separated)
* -sourceList: (optional) text file of source names to manage (one per line)
* -startTime: (optional) time to start maintenance (e.g. '2025-01-10 23:00:00')
* -endTime: (optional) time to end maintenance (e.g. '2025-01-11 05:00:00')
* -startNow: (optional) start maintenance now
* -endNow: (optional) end maintenance now
