# How to Download These PowerShell Scripts

The README.md for each script provides download commands that you can run from a powershell session. For example, to download the backupNow.ps1 script:

```powershell
# Download Commands
$scriptName = 'backupNow'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

It looks complicated, but essentially there are two `Invoke-WebRequest` commands that download two files:

* backupNow.ps1
* cohesity-api.ps1 (function library required by PowerShell scripts in this repository)

The `Get-Content` and `Set-Content` commands do the work of converting the files to the proper line endings for the local operating system (e.g. Windows, Mac, Linux).

If the download commands don't work, it's likely because the PowerShell session does not have access to the Internet, or perhaps access to GitHub is blocked. In this case, you can manually copy/paste the scripts, using the following process:

To get cohesity-api.ps1:

1. On your laptop (where Internet access is possible), open your web browser and go to <https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1>
2. Select all and copy the contents to your clipboard
3. Paste the contents into your code/text editor and save as cohesity-api.ps1

To get backupNow.ps1:

1. On your laptop (where Internet access is possible), open your web browser and go to <https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/backupNow/backupNow.ps1>
2. Select all and copy the contents to your clipboard
3. Paste the contents into your code/text editor and save as backupNow.ps1
