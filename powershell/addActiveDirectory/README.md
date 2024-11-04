# Join Active Directory Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script joins a Cohesity cluster to Active Directory.  

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'addActiveDirectory'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/exampleConfig.ps1").content | Out-File "exampleConfig.ps1"; (Get-Content "exampleConfig.ps1") | Set-Content "exampleConfig.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [addActiveDirectory.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/addActiveDirectory/addActiveDirectory.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module
* [exampleConfig.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/addActiveDirectory/exampleConfig.ps1): example configuration file

Place the files in a folder together and run the main script like so:

```powershell
# Command line example
./addActiveDirectory.ps1 -cluster mycluster `
                         -username myuser `
                         -domain local `
                         -adDomain mydomain.net `
                         -adUsername myuser@mydomain.net `
                         -adPassword bosco `
                         -adComputername mycluster `
                         -adContainer US/IT/Servers
# End example
```

## Parameters

* -cluster: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: Cohesity logon domain (defaults to local)
* -adDomain: Active Directory domain to join
* -adUsername: Active Directory admin user to join domain
* -adPassword: Password of Active Directory admin user
* -adComputername: Name of computer account to create/use
* -adContainer: (Optional) Canonical name of OU/Container for computer account (defaults to Computers)
* -useExistingComputerAccount: (optional) overwrite existing computer account
* -configFile: (Optional) provide the above parameters in a config file

## Using a Config File

If you don't want to provide all the parameters on the command line, you can provide a config file. The config file should contain any parameters you want to provide. Like so:

```powershell
# config file example

# AD Domain to join
$adDomain = 'my.domain.net'

# AD Username
$adUsername = 'myuser@my.domain.net'

# AD Password
$adPassword = 'bosco'

# AD Computername
$adComputername = 'mycluster'

# AD Conotainer
$adContainer = 'Servers/IT/Cohesity'

# End configFile
```

Save the above as a .ps1 file like myActiveDirectory.ps1 and then you can use the config file in your command, like:

```powershell
# using config file example
./addActiveDirectory.ps1 -cluster mycluster `
                         -username myuser `
                         -domain local `
                         -configFile ./myActiveDirectory.ps1
# end example
```
