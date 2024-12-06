# Download M365 Files Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script downloads files from M365 OneDrive and Sharepoint.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'downloadM365Files'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [downloadM365Files.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/downloadM365Files/downloadM365Files.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./downloadM365Files.ps1 -vip mycluster `
                        -username myusername `
                        -domain mydomain.net `
                        -objectName someuser1@mydomain.onmicrosoft.com `
                        -objectType OneDrive
```

By default, all files will be downloaded from the latest backup, but you can specify individual paths if desired:

```powershell
./downloadM365Files.ps1 -vip mycluster `
                        -username myusername `
                        -domain mydomain.net `
                        -objectName someuser1@mydomain.onmicrosoft.com `
                        -objectType OneDrive `
                        -filePath /Folder1, /Folder2/file1.txt
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

* -objectName: name of OneDrive user or Sharepoint site
* -objectType: (optional) OneDrive or Sharepoint (default is OneDrive)
* -filePath: (optional) one or more file paths to download (comma separated)
* -fileList: (optional) text file of file paths to download (one per line)
* -jobName: (optional) filter by protection group name
* -before: (optional) search only in backup before date (e,g, '2024-12-05 23:30:00')
* -after: (optional) search only in backup after date (e,g, '2024-12-04 00:00:00')
* -downloadPath: (optional) directory to download zip file to (default is '.')
* -abortOnMissing: (optional) exit if any requested files are missing
* -sleepTime: (optional) time to wait between status queries (default is 30)
