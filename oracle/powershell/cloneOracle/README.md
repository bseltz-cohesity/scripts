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

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

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
* -pfileList: (optional) text file of pfile parameters (one per line)
* -clearPfileParameters: (optional) delete existing pfile parameters
* -preScript: (optional) name of script to run before clone operation
* -preScriptArguments: (optional) preScript parameters (use quotes, like: 'param1=test switch2')
* -postScript: (optional) name of script to run after clone operation
* -postScriptArguments: (optional) postScript parameters (use quotes, like: 'param1=test switch2')
* -vlan: (optional) VLAN ID to connect to the target host through

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-latest** parameter.

Or, if you want to replay logs to a specific point in time, use the **-logTime** parameter and specify a date and time in military format like so:

```powershell
-logTime '2019-01-20 23:47:02'
```

## PFile Parameters

Note: the number and order of pfileParameterNames must match the number and order of pfileParameterValues.

By default, Cohesity will generate a list of pfile parameters from the source database, with basic adjustments for the target database. You can override this behavior in a few ways.

* You can add or override individual pfile parameters using -pfileParameterName and -pfileParameterValue, e.g. `-pfileParameterName DB_RECOVERY_FILE_DEST_SIZE -pfileParameterValue "32G"`
* You can provide a text file containing multiple pfile parameters using -pfileList, e.g. `-pfileList ./my_pfile.txt`
* You can clear all existing pfile parameters and provide a complete pfile using -clearPfileParameters and -pfileList, e.g. `-clearPfileParameters -pfileList ./my_pfile.txt`
