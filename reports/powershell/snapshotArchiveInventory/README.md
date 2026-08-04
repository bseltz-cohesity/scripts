# Snapshot and Archive Recovery Inventory using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script inventories every local snapshot, archive copy, and replicated-in copy that is currently available for recovery across one or more Cohesity clusters (directly, or Helios/MCM-managed). Each recovery point is reported at the object level, along with where it lives (local, archive target, or source cluster) and when it expires.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'snapshotArchiveInventory'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [snapshotArchiveInventory.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/snapshotArchiveInventory/snapshotArchiveInventory.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example
./snapshotArchiveInventory.ps1 -vip mycluster -username myusername -domain mydomain.net
# end example
```

To inventory multiple clusters in a single run:

```powershell
# example
./snapshotArchiveInventory.ps1 -vip mycluster1, mycluster2 -username myusername -domain mydomain.net
# end example
```

To connect through Helios/MCM:

```powershell
# example
./snapshotArchiveInventory.ps1 -username myuser@mydomain.net -clusterName mycluster1, mycluster2
# end example
```

When connecting through Helios/MCM, if `-clusterName` is omitted, every cluster visible to that account is inventoried automatically.

All clusters in a run are written to one combined output file - each row already carries its own `Cluster Name` column, so there's no need to merge separate files afterward.

## Authentication Parameters

* -vip: (optional) one or more names or IPs of Cohesity clusters, comma separated (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mcm: (optional) connect through Helios/MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) request an emailed MFA code
* -tenant: (optional) tenant to impersonate
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM (comma separated). If omitted, every cluster visible to the account is inventoried.

## Other Parameters

* -jobName: (optional) one or more protection group names to include, comma separated (default is all protection groups)
* -jobList: (optional) path to a text file of protection group names to include, one per line
* -days: (optional) only include runs that started within the last N days (default is all history)
* -includeExpired: (optional) also report snapshots/archives that are expired or manually deleted, and include the full run history rather than just currently-restorable runs
* -unit: (optional) KiB, MiB, GiB or TiB (default is GiB)
* -smtpServer: (optional) outbound SMTP server, to email the report
* -smtpPort: (optional) outbound SMTP port (default is 25)
* -sendTo: (optional) one or more email addresses to send the report to, comma separated
* -sendFrom: (optional) email address to send the report from

## Column Descriptions (`snapshotArchiveInventory-<date>.tsv`)

| Col | Column Name | Description
| --- | --- | ---
| A | **Cluster Name** | The name of the Cohesity cluster where the recovery point resides.
| B | **Tenant** | The name of the tenant(s) with permissions on the Protection Group, if multi-tenancy is in use.
| C | **Job Name** | The name of the Cohesity Protection Group (backup job) that protects this object.
| D | **Environment** | The Cohesity environment/workload type for the protected object (e.g., `VMware`, `SQL`, `Oracle`, `Physical`).
| E | **Run Type** | The backup run type: `Incremental`, `Full`, `Log`, or `System`.
| F | **Run Start Time** | When the protection group run started.
| G | **Object Name** | The name of the individual protected object - a VM name, database name, volume, etc.
| H | **Registered Source** | The registered protection source that owns this object (e.g. the vCenter server or SQL host). Mirrors Object Name if there's no parent source.
| I | **Recovery Type** | Where this copy lives: `Local` (on this cluster), `Replicated` (landed on this cluster via replication from another cluster), or `Archive` (on an external target).
| J | **Target Name** | For `Archive` rows, the archive target's name. For `Replicated` rows, the source cluster's name. Blank for `Local` rows.
| K | **Target Type** | For `Archive` rows, the target type (`Cloud`, `Tape`, or `Nas`). For `Replicated` rows, `Cluster`. Blank for `Local` rows.
| L | **Snapshot Start Time** | When this specific copy's backup/archive/replication attempt started.
| M | **Snapshot End Time** | When this specific copy's attempt completed.
| N | **Expiration Time** | When this copy is scheduled to expire and no longer be recoverable. Blank means no expiration is set (kept until otherwise deleted).
| O | **Status** | The outcome of this copy's attempt (e.g. `Succeeded`, `SucceededWithWarning`, `Failed`). Normalized to one vocabulary regardless of whether the API reported it in the local snapshot style (`kSuccessful`) or archive/replication style (`Succeeded`).
| P | **On Legal Hold** | Whether this copy is currently on legal hold.
| Q | **Logical Size (`<unit>`)** | The logical size of this copy. For archive copies inferred from a run-level secondary copy task, this is the whole task's aggregate size across all objects, not a true per-object figure. Units are controlled by the `-unit` parameter (default GiB).
