# Remotely Deploy Cohesity Windows Agent using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script installs and configures the Cohesity Windows agent on remote hosts. This is useful when deploying the agent on new hosts. After the agent is installed, Cohesity can push out aget upgrades from the UI.

## Components

* deployWindowsAgent.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module
* UserRights.psm1: Module for setting logon as a service right (see attribution below)
* servers.txt: text file containing server names to deploy to

Place all files in a folder together, then we can run the script.

__Note: The script must be run by a user who has rights to perform actions on the remote servers__

The script can perform several steps, which can be run individually or together. The steps are:

* -installAgent: This step copies the agent installer to the remote system, runs the installer and opens the necessary port on the firewall.

* -register: This step registers the host as a Cohesity protection source (physical server). This step requires the agent to be installed and firewall port open first.

* -registerSQL: This step registers the protection source as a SQL server. This step requires the server to be registered as a protection source first.

* -sqlAccount: This step sets the Cohesity agent to logon with a specific account (the script will prompt for the password). The script will also grant the account the SEServiceLogon right.

It would be common to use all steps together as shown below if you are deploying to stand-alone SQL servers or SQL AAG nodes. For SQL Failover Clusters, just use -installAgent and -sqlAccount, then register the SQL cluster manually in the UI (I may add code in the future to handle clusters).

```powershell
.\deployWindowsAgent.ps1 -vip mycluster -username admin -domain local -serverList .\sqlServers.txt -installAgent -register -registerSQL -sqlAccount mydomain.net\myuser
```
```text
Connected!
Enter password for mydomain.net\myuser: ********
managing Cohesity Agent on sqlserver1.mydomain.net
    copying agent installer...
    installing Cohesity agent...
    Registering as Cohesity protection source...
    Setting CohesityAgent Service Logon Account...
    Registering as SQL protection source...
managing Cohesity Agent on sqlserver2.mydomain.net
    copying agent installer...
    installing Cohesity agent...
    Registering as Cohesity protection source...
    Setting CohesityAgent Service Logon Account...
    Registering as SQL protection source...
```

## Attributions

* UserRights.psm1: was downloaded from: https://gallery.technet.microsoft.com/scriptcenter/Grant-Revoke-Query-user-26e259b0 thanks to Tony MCP: https://social.technet.microsoft.com/profile/tony%20mcp/ just what I was looking for!


