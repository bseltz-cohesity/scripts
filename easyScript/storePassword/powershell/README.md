# Store EasyScript Password Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script finds stores a password for use with EasyScript

## Download the Script

You can download the scripts using the following commands:

```powershell
# Download Commands
$scriptName = 'storePassword'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/easyScript'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/powershell/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Storing a Password

Run the script like so:

```powershell
.\storePassword.ps1
Enter password for local/helios at helios.cohesity.com: ************************************
```

or

```powershell
.\storePassword.ps1 -vip mycluster -username myuser -domain mydomain.net
Enter password for mydomain.net/myuser at mycluster: **********
```

Passwords are obfuscated and stored in a file called YWRtaW4. Once the password is stored, zip this file along with the other script files for upload to EasyScript.

## Arguments

* -vip: (optional) DNS or IP of the Helios endpoint (defaults to helios.cohesity.com)
* -username: (optional) username to store helios API key (defaults to helios)
* -domain: (optional) domain of username to store helios API key (default is local)
