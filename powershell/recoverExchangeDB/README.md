# Recover Exchange Mailbox Database using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers an Exchange mailbox database to a Cohesity view.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoverExchangeDB'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [recoverExchangeDB.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/recoverExchangeDB/recoverExchangeDB.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./recoverExchangeDB.ps1 -vip mycluster `
                        -username myusername `
                        -domain mydomain.net ` 
                        -dbName 'Mailbox Database 1173012194' `
                        -targetServer exchange01.mydomain.net
```

to tear down later:

```powershell
./recoverExchangeDB.ps1 -vip mycluster `
                        -username myusername `
                        -domain mydomain.net ` 
                        -dbName 'Mailbox Database 1173012194' `
                        -targetServer exchange01.mydomain.net `
                        -tearDown
```

to perform user defined actions and tear down immediately after:

```powershell
./recoverExchangeDB.ps1 -vip mycluster `
                        -username myusername `
                        -domain mydomain.net ` 
                        -dbName 'Mailbox Database 1173012194' `
                        -targetServer exchange01.mydomain.net `
                        -tearDownAfter
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -dbName: name of mailbox DB to recover
* -targetServer: name of server to mount to
* -recoverDate: (optional) e.g. '2021-08-18 23:30:00' (will use most recent at or before this date)
* -teardown: (optional) tear down existing recovery view
* -teardownSearchDays: (optional) days back to search to recovery views to teardown (default is 7)
* -teardownAfter: (optional) tear down after user defined commands
* -destination: (optional) destination directory for file copy

## User defined actions

There is a commented section of the script where you can put additional commands to complete the recovery of the exchange database:

```powershell
    # BEGIN USER DEFINED RECOVERY STEPS =================================

    # stop exchange
    # COPY-ITEM -Path $mountPoint\* -Destination $destination
    # check db
    # start exchange

    # END USER DEFINED RECOVERY STEPS ===================================
```
