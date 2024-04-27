# List Active Replicated Snapshot Counts Per Protected Object

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script lists the active snapshot count for every protected object that was replicated other Cohesity clusters. The goal is to produce an inventory of snapshots available on replica clusters that are not reachable directly (e.g. vault clusters).

Note: this script requires the source cluster to be connected to Helios.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'activeSnapshotsRemote'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [activeSnapshotsRemote.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/activeSnapshotsRemote/activeSnapshotsRemote.ps1): the main python script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

Faster option (query run info directly from cluster):

```bash
# example
./activeSnapshotsRemote.ps1 -heliosUser helios `
                            -sourceCluster mycluster1 `
                            -clusterUsername myusername `
                            -domain mydomain.net
# end example
```

Slower option (query run info proxied through Helios):

```bash
# example
./activeSnapshotsRemote.ps1 -heliosUser helios `
                            -sourceCluster mycluster1
# end example
```

## Helios Authentication Parameters

* -heliosVip: (optional) name or IP of helios or MCM (defaults to helios.cohesity.com)
* -heliosUsername: (optional) name of user to connect to Cohesity (defaults to helios)
* -sourceCluster: name of the Helios-connected cluster that is the source of the replications

## Cluster Authentication Parameters

* -clusterVip: (optional) will use clusterName if omitted
* -clusterUsername: (optional) will connect through Helios/MCM if omitted (slower)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code

## Other Parameters

* -remoteCluster: (optional) name of replica cluster to inspect (target of the replications)
* -days: (optional) limit query to the last X days (default is 90)
* -dayRange: (optional) chunk helios query to X day ranges (default is 7)
* -pageSize: (optional) API paging (default is 1000)
* -environment: (optional) one or more types (comma separated) to include in query (e.g. kSQL, kVMware)
* -excludeEnvironment: (optional) one or more types (comma seaparated) to exclude from query  (e.g. kSQL, kVMware)
* -ouputPath: (optional) path to write output file (default is '.')
* -omitSourceClusterColumn: (optional) do not include source cluster column in the output file
