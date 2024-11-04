# Remotely Deploy Cohesity CCS Windows Agent using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script installs and configures the Cohesity CCS Windows agent on remote hosts. This is useful when deploying the agent on new hosts. After the agent is installed, Cohesity can push out aget upgrades from the UI.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/deployCCSWindowsAgent/deployCCSWindowsAgent.ps1).content | Out-File deployCCSWindowsAgent.ps1; (Get-Content deployCCSWindowsAgent.ps1) | Set-Content deployCCSWindowsAgent.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployWindowsAgent/UserRights.psm1).content | Out-File UserRights.psm1; (Get-Content UserRights.psm1) | Set-Content UserRights.psm1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [deployCCSWindowsAgent.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployCCSWindowsAgent/deployCCSWindowsAgent.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module
* [UserRights.psm1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployCCSWindowsAgent/UserRights.psm1): Module for setting logon as a service right (see attribution below)
* servers.txt: text file containing server names to deploy to

Place all files in a folder together, then we can run the script.

Note: The script must be run by a user who has rights to perform actions on the remote servers

The script can perform several steps, which can be run individually or together. The steps are:

* -installAgent: This step copies the agent installer to the remote system, runs the installer and opens the necessary port on the firewall.

* -register: This step registers the host as a Cohesity protection source (physical server). This step requires the agent to be installed and firewall port open first.

* -registerAD: This step registers the host as an Active Directory domain controller. This step requires the server to be registered as a protection source first.

* -registerSQL: This step registers the protection source as a SQL server. This step requires the server to be registered as a protection source first.

* -serviceAccount: This step sets the Cohesity agent to logon with a specific account (the script will prompt for the password). The script will also grant the account the SEServiceLogon right.

It would be common to use all steps together as shown below if you are deploying to stand-alone SQL servers or SQL AAG nodes. For SQL Failover Clusters, just use -installAgent and -sqlAccount, then register the SQL cluster manually in the UI (I may add code in the future to handle clusters).

```powershell
# example
.\deployCCSWindowsAgent.ps1 -username myuser@mydomain.net -region us-west-2 -serverList .\sqlServers.txt -installAgent -saasConnector 'my saas connector' -register -registerSQL -serviceAccount mydomain.net\myuser
# end example
```

## Authentication Parameters

* -username: name of user to connect to Cohesity
* -region: your AD domain (defaults to local)
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password

## Other Parameters

* -serverList: (optional) path to file containing servernames to deploy to
* -server: (optional) name of one server to deploy to
* -storePassword: (optional) store service account password (encrypted) for later script runs
* -installAgent: (optional) install the Cohesity agent
* -register: (optional) register server as a Cohesity physical protection source
* -registerSQL: (optional) register server as a MSSQL protection source (requires -register or previous registration)
* -sqlCluster: (optional) register server as a MSSQL Failover Cluster node (requires -register or previous registration)
* -serviceAccount: (optional) set Cohesity agent to run using a service account
* -filePath : (optional) use existing agent file (will download latest by default)

## Attributions

* [UserRights.psm1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployCCSWindowsAgent/UserRights.psm1): was downloaded from: <https://gallery.technet.microsoft.com/scriptcenter/Grant-Revoke-Query-user-26e259b0> thanks to Tony MCP: <https://social.technet.microsoft.com/profile/tony%20mcp/> just what I was looking for!
