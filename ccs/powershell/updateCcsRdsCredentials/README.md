# Update CCS RDS Credentials using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script updates RDS credentials in CCS.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateCcsRdsCredentials'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [updateCcsRdsCredentials.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/updateCcsRdsCredentials/updateCcsRdsCredentials.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To see the list of RDS instances:

```powershell
./updateCcsRdsCredentials.ps1 -sourceName 220923520471
```

To filter by type:

```powershell
./updateCcsRdsCredentials.ps1 -sourceName 220923520471 `
                              -rdsType kAuroraCluster
```

To filter by database engine:

```powershell
./updateCcsRdsCredentials.ps1 -sourceName 220923520471 `
                              -dbEngine aurora-postgresql15.4
```

To filter by name:

```powershell
./updateCcsRdsCredentials.ps1 -sourceName 220923520471 `
                              -rdsName db1, db2
```

To update credentials:

```powershell
./updateCcsRdsCredentials.ps1 -sourceName 220923520471 `
                              -rdsName db1, db2 `
                              -update `
                              -authType iam
                              -rdsUser myuser
```

## Basic Parameters

* -username: (optional) username to authenticate to Helios (default is 'ccs')
* -password: (optional) API key to authenticate to Helios (will be prompted if omitted)
* -sourceName: name of registered AWS source

## Filter Parameters

* -rdsName: (optional) filter by RDS instance names (comma separated)
* -rdsList: (optional) text file of RDS instance names to filter by (one per line)
* -rdsType: (optional) filter by RDS instance type (kAuroraCluster or kRDSInstance)
* -dbEngine: (optional) filter by database engine

## Update Parameters

* -update: (optional) perform credential update
* -authType: (optional) 'credentials', 'iam' or 'kerberos' (default is 'credentials')
* -rdsUser: (optional) username for credential update
* -rdsPassword: (optional) password for credential update (required for credentials and kerberos)
* -realmName: (optional) kerberos realm name for credential update (required for kerberos)
* -realmDnsAddress: (optional) kerberos DNS address for credential update (required for kerberos)
