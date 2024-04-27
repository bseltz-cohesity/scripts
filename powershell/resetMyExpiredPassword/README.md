# Reset My Expired Password Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script resets your expired password.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'resetMyExpiredPassword'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Example

The script will prompt for passwords if omitted:

```powershell
# example
./resetMyExpiredPassword.ps1 -vip mycluster `
                             -username myusername
# end example
```

Or you can provide them on the command line:

```powershell
# example
./resetMyExpiredPassword.ps1 -vip mycluster `
                             -username myusername `
                             -currentPassword prevPassw0rd! `
                             -newPassword newPassw0rd! `
                             -confirmNewPassword newPassw0rd!
# end example
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -currentPassword: (optional) will be prompted if omitted
* -newPassword: (optional) will be prompted if omitted
* -confirmNewPassword: (optional) will be prompted if omitted
