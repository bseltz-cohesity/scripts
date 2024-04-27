# Create a NetApp User for Cohesity Backups using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates a NetApp user and role with the required permissions to register a NetApp protection source in Cohesity.

**Note:** This script required NetApp release 9.6 or later and also requires the NetApp PowerShell Toolkit to be installed.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'netappCreateCohesityUser'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

You can run the main script like so:

```powershell
./netappCreateCohesityUser.ps1 -netapp mynetapp `
                               -username myusername `
                               -cohesityUsername cohesity
```

You will first be prompted for your NetApp password (to connect to NetApp), and then you will be prompted for the password for the new user.

## Parameters

* -netapp: DNS name or IP of the NetApp to connect to
* -username: user name to connect to NetApp
* -password: (optional) will prompt if omitted
* -cohesityUsername: user name to connect to NetApp
* -cohesityPassword: (optional) will prompt if omitted
* -vServer: (optional) name of vServer to create the account for (default is cluster wide)
* -createSMBUser: (optional) create a CIFS user and role in the vServer
* -delete: (optional) delete a user
