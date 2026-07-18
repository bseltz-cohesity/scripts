# Download Ccs M365 OneDrive/SharePoint Files using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script searches for a protected M365 OneDrive or SharePoint object in Cohesity Cloud Services (Ccs), locates one or more files/folders within a backup snapshot, and downloads them as a zip file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'downloadCCSM365Files'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [downloadCCSM365Files.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/downloadCCSM365Files/downloadCCSM365Files.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# download from onedrive
./downloadCCSM365Files.ps1 -region us-east-2 `
                           -objectName someuser@mydomain.onmicrosoft.com `
                           -filePath '/Documents/report.docx' `
                           -objectType OneDrive

# download from sharepoint
./downloadCCSM365Files.ps1 -region us-east-2 `
                           -objectName 'Communication Site' `
                           -filePath '/Site Pages/Home.aspx' `
                           -objectType Sharepoint
```

## Authentication Parameters

* -username: (optional) Ccs username, used for password storage only (default is 'helios')
* -password: (optional) Ccs API key/password (will be prompted for and stored securely if omitted)
* -noPrompt: (optional) do not prompt for a password (fails if no stored password is found)

## Basic Parameters

* -region: (required) Ccs region ID where the object is protected
* -objectName: (required) name of the OneDrive or SharePoint object to search (e.g. a user's UPN or a SharePoint site name)
* -sourceName: (optional) name of the M365 source, used to disambiguate when multiple objects share the same name
* -objectType: (optional) 'OneDrive' or 'Sharepoint' (default is 'OneDrive')

## File Selection Parameters

* -filePath: (optional) one or more file or folder paths to download (can be repeated); if omitted, all files in the snapshot are downloaded
* -fileList: (optional) path to a text file containing a list of file/folder paths (one per line) to download
* -before: (optional) only consider snapshots taken before this date/time (e.g. '2026-06-01 00:00:00')
* -after: (optional) only consider snapshots taken after this date/time (e.g. '2026-05-01 00:00:00')
* -abortOnMissing: (optional) abort the script if any specified paths are not found (default is to report missing paths and continue)

## Other Parameters

* -downloadPath: (optional) folder to save the downloaded zip file(s) to (default is '.')
* -sleepTimeSeconds: (optional) seconds to sleep between recovery status checks (default is 30)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> Access Management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
