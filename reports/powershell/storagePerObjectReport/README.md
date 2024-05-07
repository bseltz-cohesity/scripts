# Generate Estimated Storage Per Object Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates a report of estimated storage consumption per object. Note that this report performs estimation so is not expected to be completely accurate.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'storagePerObjectReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [storagePerObjectReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/storagePerObjectReport/storagePerObjectReport.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example
./storagePerObjectReport.ps1 -vip mycluster -username myusername -domain mydomain.net
# end example
```

To report on multiple clusters:

```powershell
# example
./storagePerObjectReport.ps1 -vip mycluster1, mycluster2 -username myusername -domain mydomain.net
# end example
```

To connect through Helios:

```powershell
# example
./storagePerObjectReport.ps1 -username myuser@mydomain.net -clusterName mycluster1, mycluster2
# end example
```

## Authentication Parameters

* -vip: (optional) one or more names or IPs of Cohesity clusters, comma separated (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM (comma separated)

## Other Parameters

* -numRuns: (optional) number of runs per API query (default is 1000)
* -growthDays: (optional) number of days to measure recent growth (default is 7)
* -skipDeleted: (optional) skip deleted protection groups
* -unit: (optional) MiB, GiB, TiB, MB, GB or TB (default is GiB)
* -outfileName: (optional) specify name for output csv file
* -consolidateDBs: (optional) hide Oracle and SQL databases and only show the parent host
* -includeArchives: (optional) get per object stats for external targets

## Column Descriptions

Index | Name | Description
--- | --- | ---
A | Cluster Name | name of cluster queried
B | Origin | local or replica
C | Stats Age | age (days) of stats (should be 2 or less)
D | Protection Group | name of protection group
E | Tenant | name of organization
F | Storage Domain ID | ID of storage domain
G | Storage Domain Name | name of storage domain
H | Environment | protection group type
I | Source Name | name of registered source (e.g. vCenter, server, etc.)
J | Object Name | name of object (e.g. VM, NAS share, database, etc.)
K | Front End Allocated | front-end allocated size of object as reported by the source
L | Front End Used | front-end used size of object as reported by the source
M | Before Reduction | amount of data ingested and retained for this object, before dedup/compression
N | After Reduction | amount of data ingested and retained for this object, after deduped/compression (before adding resiliency striping overhead)
O | After Reduction plus Resiliency (Raw) | amount of data ingested and retained for this object, after deduped/compression (after adding resiliency striping overhead)
P | Reduction Ratio | dedup/compression ratio of protection group
Q | Raw Change Last X Days | change of Raw consumption for this object, in past X days
R | Snapshots | number of local backups resident on Cohesity
S | Log Backups | number of log backups (if applicable) resident on Cohesity
T | Oldest Backup | oldest backup resident on Cohesity
U | Newest Backup | newest backup resident on Cohesity
V | Archive Count | number of archives stored in external targets
W | Oldest Archive | oldest archive available for restore
X | GiB Archived | amount of deduped/compressed data, for this object, resident on cloud archive targets
Y | GiB per Archive Target | amount of deduped/compressed data, for this object, resident on each archive target
Z | Description | description of protection group or view
AA | VMWare Tags | VMWare Tags assigned to VM
