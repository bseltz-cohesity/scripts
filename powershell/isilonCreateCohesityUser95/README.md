# Create an Isilon User for Cohesity Backups using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates an Isilon user and role with the required permissions to register an Isilon protection source in Cohesity.

This version of the script supports Isilon 9.5 stricter security requirements.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'isilonCreateCohesityUser95'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/isilon-api.ps1").content | Out-File "isilon-api.ps1"; (Get-Content "isilon-api.ps1") | Set-Content "isilon-api.ps1"
# End Download Commands
```

You can run the main script like so:

```powershell
./isilonCreateCohesityUser95.ps1 -isilon myisilon `
                                 -username myusername `
                                 -cohesityUsername cohesity
```

You will first be prompted for your isilon password (to connect to Isilon), and then you will be prompted for the password for the new user.

## Parameters

* -isilon: DNS name or IP of the Isilon to connect to
* -username: user name to connect to Isilon
* -password: (optional) will prompt if omitted
* -cohesityUsername: user name to connect to Isilon
* -cohesityPassword: (optional) will prompt if omitted
* -createSMBUser: (optional) create SMB user and BackupAdmin role for all zones
* -delete: (optional) delete API and SMB user and roles from all zones and exit
