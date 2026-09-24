# Collect a Timecapsule Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script collects a Cohesity Timecapsule (support bundle), then downloads it locally.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'collectTimeCapsule'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [collectTimeCapsule.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/collectTimeCapsule/collectTimeCapsule.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./collectTimeCapsule.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -hoursBack 24
```

## Authentication Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity cluster
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code

## Collection Parameters

* -outpath: (optional) local directory to download to (defaults to the current directory)
* -nodeIps: (optional) comma separated node IPs to collect from (defaults to all nodes)
* -services: (optional) comma separated service names to collect logs for (defaults to all services)
* -listServices: (optional) print the list of valid service names, then exit
* -msgTypes: (optional) comma separated log message types to collect (default: INFO,WARNING,ERROR,FATAL)
* -criticalLogsOnly: (optional) collect FATAL logs only
* -forceDelete: (optional) force delete old timecapsules
* -hoursBack: (optional) collect logs from N hours ago until now, in UTC (default: 4; the cluster caps this at 48 hours)
* -outputDir: (optional) directory on the cluster node(s) to write the bundle to (default: /home/cohesity/data/timecapsules)

## Advanced Options

* -pollIntervalSecs: (optional) seconds between polls while waiting for the bundle to appear and finish writing (default: 15)
* -pollWaitMins: (optional) minutes to wait for the collection to finish before giving up (default: 30)
* -dbg: (optional) print the full request URL before submitting it, and the HTTP status/byte count of the response

## Examples

Collect the last 4 hours of logs from every node/service, using defaults:

```powershell
./collectTimeCapsule.ps1 -vip mycluster -username myusername -domain mydomain.net
```

Collect the last 24 hours, deleting any existing Timecapsule directory content on the node(s) first:

```powershell
./collectTimeCapsule.ps1 -vip mycluster `
                -username myusername `
                -domain mydomain.net `
                -hoursBack 24 `
                -forceDelete
```

Collect from specific nodes and services only:

```powershell
./collectTimeCapsule.ps1 -vip mycluster `
                -username myusername `
                -domain mydomain.net `
                -nodeIps 10.1.1.10,10.1.1.11 `
                -services apollo,stargate,bridge
```

Collect FATAL-only critical logs:

```powershell
./collectTimeCapsule.ps1 -vip mycluster -username myusername -domain mydomain.net -criticalLogsOnly
```

List the service names Siren considers valid for a cluster without collecting anything:

```powershell
./collectTimeCapsule.ps1 -vip mycluster -username myusername -domain mydomain.net -listServices
```

Troubleshoot a request that doesn't seem to be doing anything, by seeing exactly what's being sent:

```powershell
./collectTimeCapsule.ps1 -vip mycluster `
                -username myusername `
                -domain mydomain.net `
                -hoursBack 24 `
                -dbg
```
