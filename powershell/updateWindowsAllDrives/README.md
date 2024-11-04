# Update Windows File-Based Protection to Protect All Local Drives Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script updates physical file-based Windows protection to protect all local drives, if only the C drive is protected (the default).

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateWindowsAllDrives'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* updateWindowsAllDrives.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./updateWindowsAllDrives.ps1 -vip mycluster -username myusername -domain mydomain.net
```

## Authentication Parameters

* -vip: name or IP of Cohesity cluster
* -username: (optional) name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email

## Other Parameters

* -jobName: (optional) one or more job names to modify (comma separated)
* -jobList: (optional) text file of job names to modify (one per line)
* -commit: (optional) commit changes (if omitted, only show what it would do)
* -skipHostsWithExcludes: (optional) skip hosts with excludes present
