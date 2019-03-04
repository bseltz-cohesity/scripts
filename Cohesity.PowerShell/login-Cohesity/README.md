# Use Stored Passwords with Cohesity.PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script allows you to securely use stored credentials with the Cohesity.Pwershell cmdlet Connect-CohesityCluster.

Note: the Cohesity.PowerShell cmdlets can be found here: https://cohesity.github.io/cohesity-powershell-module/#/setup

The first time you use the script and use a username to authenticate to a Cohesity cluster, the script will prompt you for your password. The password will be encrypted and stored for later use. The second time you run the script with the same username and cluster, you will not be prompted for your password.

## Components

* login-Cohesity.ps1: the main PowerShell script

You can run the scipt like so:

```powershell
./login-Cohesity.ps1 -Server mycluster -UserName myusername -Domain mydomain.net
```
```text
Connected to the Cohesity Cluster mycluster Successfully
```

## Optional Parameters

*  -UpdatePassword: (optional) force the script to prompt for a new password
*  -Domain: (optional) defaults to 'local', otherewise enter your AD domain e.g. mydomain.net

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/Cohesity.PowerShell/login-Cohesity/login-Cohesity.ps1).content | Out-File login-Cohesity.ps1
```
