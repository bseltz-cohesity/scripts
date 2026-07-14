# EPIC Cache/IRIS Throughput Calculator (PowerShell)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script estimates Full, Incremental, and Pure Incremental backup durations (and the resulting restore duration) for an EPIC Cache/IRIS (operational database) mount host, and identifies the throughput bottleneck for each. Given the mount host's database size, FC and NIC connectivity, and the Cohesity cluster's node count and ingest speed, it prints the estimated durations and bottlenecks to the screen.

## Download the script

Run these commands from PowerShell to download the script into your current directory

```powershell
# Download Commands
$scriptName = 'epicThroughputCalculator'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Usage

```powershell
./epicThroughputCalculator.ps1 -ODBSizeTB 70 `
                               -FcSpeedGb 32 `
                               -NicSpeedGb 25 `
                               -ClusterNodes 8 `
                               -NodeSpeedMBps 150
```

## Parameters

* -ODBSizeTB: Iris/Cache database size, in TB, that will be backed up / restored
* -FcSpeedGb: (optional) the mount host's FC bandwidth to the storage array, in Gigabits (defaults to `32`)
* -NicSpeedGb: (optional) the mount host's NIC bandwidth to the Cohesity cluster, in Gigabits (defaults to `10`)
* -ClusterNodes: number of nodes in the Cohesity cluster
* -NodeSpeedMBps: (optional) per-node write bandwidth of the Cohesity cluster, in MBps (defaults to `150`)
* -NodeClass: (optional) `HYBRID` or `FLASH` -- if set to `FLASH` and `-NodeSpeedMBps` is less than `400`, it's automatically raised to `400` (defaults to `HYBRID`)

## Examples

Basic usage:

```powershell
./epicThroughputCalculator.ps1 -ODBSizeTB 70 `
                               -ClusterNodes 8
```

Using additional parameters, for an all-flash cluster:

```powershell
./epicThroughputCalculator.ps1 -ODBSizeTB 70 `
                               -FcSpeedGb 32 `
                               -NicSpeedGb 25 `
                               -ClusterNodes 8 `
                               -NodeClass FLASH
```

## What the output shows

* **Inputs**: the values used for the calculation, including the FC and NIC speeds at their effective (derated) throughput alongside the raw Gb rating, and the cluster's effective ingest throughput.
* **Results -- Mount Host Method**: Full Backup, Incremental Backup, and Restore durations, each with the throughput path identified as the bottleneck (Cluster, Network, or Backend Storage).
* **Results -- Pure Method**: Pure Incremental Backup duration and bottleneck.

Each duration is the slowest of three throughput paths for that backup type: Lun Read (FC), Transfer (NIC), and Cluster Ingest. The reported bottleneck tells you which one to address first if you need to shorten that duration.
