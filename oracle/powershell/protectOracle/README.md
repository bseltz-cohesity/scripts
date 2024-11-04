# Protect Oracle using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script protects Oracle Databases.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectOracle'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/oracle/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectOracle.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/protectOracle/protectOracle.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script.

```powershell
# add one database to an existing protection job
./protectOracle.ps1 -vip mycluster -username admin -jobname 'Oracle Backup' -servervmname oracle1.mydomain.net -dbname myDB
# end
```

or:

```powershell
# add all databases on a server to an existing protection job
./protectOracle.ps1 -vip mycluster -username admin -jobname 'Oracle Backup' -servervmname oracle1.mydomain.net
# end
```

or:

```powershell
# add all databases on a server to a new protection job
./protectOracle.ps1 -vip mycluster -username admin -jobname 'New Oracle Backup' -policyname 'My Policy' -servername oracle1.mydomain.net
# end
```

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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobname: name of protection job (new or existing)
* -servername: (optional) one or more names of Oracle servers to protect (comma separated)
* -serverlist: (optional) text file of names of Oracle servers to protect (one per line)
* -dbName: (optional) one or more database names to unprotect (comma separated)
* -dbList: (optional) text file of database names to unprotect (one per line)
* -channels: (optional) number of RMAN channels to use
* -channelNode: (optional) name of RAC oracle node to use for backup
* -channelPort: (optional) Oracle port (Default is 1521)
* -deleteLogDays: (optional) delete archive logs after X days (default is no delete)
* -deleteLogHours: (optional) delete archive logs after X hours (default is no delete)

## New Job Parameters

* -policyName: (optional) name of protection policy to use
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
