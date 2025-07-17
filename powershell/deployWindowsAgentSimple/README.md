# Remotely Deploy Cohesity Windows Agent using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script installs and configures the Cohesity Windows agent on remote hosts. This is useful when deploying the agent on new hosts. After the agent is installed, Cohesity can push out aget upgrades from the UI.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployWindowsAgentSimple/deployWindowsAgentSimple.ps1).content | Out-File deployWindowsAgentSimple.ps1; (Get-Content deployWindowsAgentSimple.ps1) | Set-Content deployWindowsAgentSimple.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployWindowsAgentSimple/UserRights.psm1).content | Out-File UserRights.psm1; (Get-Content UserRights.psm1) | Set-Content UserRights.psm1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [deployWindowsAgentSimple.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployWindowsAgentSimple/deployWindowsAgentSimple.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module
* [UserRights.psm1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployWindowsAgentSimple/UserRights.psm1): Module for setting logon as a service right (see attribution below)
* servers.txt: text file containing server names to deploy to

Place all files in a folder together, then we can run the script.

Note: The script must be run by a user who has rights to perform actions on the remote servers

The script can perform several steps, which can be run individually or together. The steps are:

* -installAgent: This step copies the agent installer to the remote system, runs the installer and opens the necessary port on the firewall.

* -serviceAccount: This step sets the Cohesity agent to logon with a specific account (the script will prompt for the password). The script will also grant the account the SEServiceLogon right. Service account must be entered as `DOMAINNAME\username` or `.\localusername`

It would be common to use all steps together as shown below if you are deploying to stand-alone SQL servers or SQL AAG nodes. For SQL Failover Clusters, just use -installAgent and -sqlAccount, then register the SQL cluster manually in the UI (I may add code in the future to handle clusters).

```powershell
# example
.\deployWindowsAgentSimple.ps1 -vip mycluster -username admin -domain local -serverList .\sqlServers.txt -installAgent -serviceAccount mydomain.net\myuser
# end example
```

```text
Connected!
Enter password for mydomain.net\myuser: ********
managing Cohesity Agent on sqlserver1.mydomain.net
    copying agent installer...
    installing Cohesity agent...
    Setting CohesityAgent Service Logon Account...
managing Cohesity Agent on sqlserver2.mydomain.net
    copying agent installer...
    installing Cohesity agent...
    Setting CohesityAgent Service Logon Account...
```

## Parameters

* -filepath: path the Cohesity Windows Agent installer file
* -serverName: (optional) name of one server to deploy to
* -serverList: (optional) path to file containing servernames to deploy to
* -storePassword: (optional) store service account password (encrypted) for later script runs
* -installAgent: (optional) install the Cohesity agent
* -serviceAccount: (optional) set Cohesity agent to run using a service account
* -cbtType: (optional) onlyagent, volcbt, fscbt, or allcbt (default is allcbt)
* -tempPath: (optional) SMB share path to copy the installer, in the format sharename\path (default is admin$\Temp)

## Attributions

* [UserRights.psm1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deployWindowsAgentSimple/UserRights.psm1): was downloaded from: <https://gallery.technet.microsoft.com/scriptcenter/Grant-Revoke-Query-user-26e259b0> thanks to Tony MCP: <https://social.technet.microsoft.com/profile/tony%20mcp/> just what I was looking for!
