# Test Firewall Port Access to NetApp using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script tests that the ports required for Cohesity to protect a Netapp are accessible. Any blocked ports will be highlighted in yellow.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'netappPortTest'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

You can run the main script like so:

```powershell
./netappPortTest.ps1 -netapp mynetapp `
                     -username myusername
```

## Parameters

* -netapp: DNS name or IP of the NetApp to connect to
* -username: user name to connect to NetApp
* -password: (optional) will prompt if omitted
