# Register Oracle Sources using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script registers physical servers as Oracle servers.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'registerOracle'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/oracle/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [registerOracle.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/registerOracle/registerOracle.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module
* servers.txt: an optional text file containing a list of serversto add to the protection job

Place all files in a folder together. Optionally create a text file called servers.txt and populate with the servers that you want to protect, like so:

```text
server1.mydomain.net
server2.mydomain.net
server3.mydomain.net
```

Note that the servers in the text file must be registered in Cohesity, and should match the name format as shown in the Cohesity UI.

Then, run the main script like so:

```powershell
./registerOracle.ps1 -vip mycluster -username myusername -server myerver
```

or

```powershell
./registerOracle.ps1 -vip mycluster -username myusername -serverList ./servers.txt
```

```text
Connected!
Registering server1.mydomain.net as a Oracle protection source...
Registering server2.mydomain.net as a Oracle protection source...
Registering server3.mydomain.net as a Oracle protection source...
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: your AD domain (defaults to local)
* -server: name of a single server to add to the job
* -serverList: a text file list of servers to add to the job
* -dbUser: (optional) username for DB authentication
* -dbPassword: (optional) password for DB authentication
