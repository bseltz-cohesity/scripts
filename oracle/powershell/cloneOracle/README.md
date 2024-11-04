# Cohesity REST API PowerShell Example - Instant Oracle Clone

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an Oracle Clone Attach using PowerShell. The script takes a thin-provisioned clone of the latest backup of an Oracle database and attaches it to an Oracle server.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneOracle'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/oracle/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneOracle.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/cloneOracle/cloneOracle.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./cloneOracle.ps1 -vip mycluster -username myusername -domain mydomain.net `
                                 -sourceServer oracle.mydomain.net -sourceDB cohesity `
                                 -targetServer oracle2.mydomain.net -targetDB clonedb `
                                 -oracleHome /home/oracle/app/oracle/product/11.2.0/dbhome_1 ` 
                                 -oracleBase /home/oracle/app/oracle
```

The script takes the following parameters:

* -vip: (DNS or IP of the Cohesity Cluster)
* -username: (Cohesity User Name)
* -domain: (optional) defaults to 'local'
* -sourceServer: source Oracle Server Name
* -sourceDB: source Database Name
* -oracleHome: oracle home path
* -oracleBase: oracle base path
* -targetServer: (optional) Oracle Server to attach clone to, defaults to same as sourceServer
* -targetDB: (optional) target Database Name, defaults to same as sourceDB
* -logTime: (optional) point in time to replay the logs to. If omitted will default to time of latest DB backup
* -channels: (optional) Number of restore channels
* -channelNode: (optional) RAC node to use for channels
* -latest: (optional) replay the logs to the latest point in time available
* -wait: (optional) wait for completion and report end status
* -pfileParameterName: (optional) one or more parameter names to include in pfile (comma seaparated)
* -pfileParameterValue: (optional) one or more parameter values to include in pfile (comma separated)
* -preScript: (optional) name of script to run before clone operation
* -preScriptArguments: (optional) preScript parameters (use quotes, like: 'param1=test switch2')
* -postScript: (optional) name of script to run after clone operation
* -postScriptArguments: (optional) postScript parameters (use quotes, like: 'param1=test switch2')
* -vlan: (optional) VLAN ID to connect to the target host through

Note: the number and order of pfileParameterNames must match the number and order of pfileParameterValues.
