# EPIC Cache/IRIS gFlag Tuning Script (PowerShell)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script calculates recommended Cohesity cluster and agent gflag settings for tuning EPIC Cache/IRIS (operational database) backup performance on physical Linux or AIX mount hosts -- replacing the `Auto tuning Gflags for epic backups for linux_AIX physical.xlsx` spreadsheet previously used for this. Given a handful of inputs about the cluster and mount host, it prints the recommended settings to the screen and writes them -- along with ready-to-paste commands and instructions to apply them -- to a text file.

A bash version (`epicGflagRecommendations.sh`) covering the same logic is also available for Linux/Mac users.

Please refer to the following Confluence page: "How to Configure and Tune - Epic Cache/Iris for best performance" for more details.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'epicGflagRecommendations'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Usage

```powershell
./epicGflagRecommendations.ps1 -NodeCount 19 `
                               -HostOS AIX `
                               -NicSpeed 10GbE `
                               -CpuCores 20
```

## Parameters

* -NodeCount: number of nodes in the Cohesity cluster (1-256)
* -HostOS: operating system of the EPIC mount host -- `AIX` or `LINUX`
* -NicSpeed: (optional) mount host NIC speed range -- `10GbE` or `>10GbE` (defaults to `>10GbE`)
* -CpuCores: (optional) number of CPU cores on the mount host, e.g. 2 x Intel Xeon 12-core = 24 (defaults to 24)
* -AgentEndpoint: (optional) hostname or IP of the mount host, substituted into the agent CLI commands (defaults to a placeholder you can fill in later)
* -OutputFile: (optional) path to the text file the recommendations are written to (defaults to `.\EpicGflagRecommendations.txt`)

## Example

Basic usage:

```powershell
./epicGflagRecommendations.ps1 -NodeCount 8 `
                               -HostOS LINUX
```

Using additional parameters:

```powershell
./epicGflagRecommendations.ps1 -NodeCount 8 `
                               -HostOS LINUX `
                               -NicSpeed ">10GbE" `
                               -CpuCores 32 `
                               -AgentEndpoint epic-mount01.hospital.local `
                               -OutputFile C:\Temp\epic01-gflags.txt
```

## What the output file contains

* **Recommended Settings**: every applicable gflag, its recommended and default value, and the command to set it.
* **Cluster iris_cli Commands (paste-ready)**: the cluster-level commands with the leading `iris_cli` stripped off, ready to paste into an already-open `iris_cli` session.
* **Agent magneto_agent_debug_tool Commands (paste-ready)**: the agent-level commands, run from an SSH session on the Cohesity cluster.
* **Agent Config File Stanza**: the same agent gflags as a `user_settings { gflag_setting_vec { ... } }` block, for editing the agent config file directly instead of using `magneto_agent_debug_tool`.
* **env.sh Settings** (AIX only): the two `/usr/local/cohesity/set_env.sh` values to update.
* **Restarting the Cohesity Agent**: the commands to restart the agent after applying config file or env.sh changes.

## Applying the settings

Cluster-level gflags are applied with `iris_cli`, run from any CVM or via SSH to the cluster VIP.

Agent-level gflags are applied with `magneto_agent_debug_tool`, run from an SSH session on the Cohesity cluster -- not on the mount host. As an alternative, the agent config file (`/etc/aix_agent_config.cfg` on AIX, `/etc/cohesity-agent/agent.cfg` on Linux) can be edited directly using the stanza in the output file; merge it into any existing `user_settings` block rather than adding a second one.

On AIX, the two `set_env.sh` values already exist in the file and just need their values updated.

After making any config file or `set_env.sh` change, restart the Cohesity agent using the commands in the output file, then kick off a test backup and monitor throughput before rolling out further.

## Notes

* This script only calculates and prints/writes recommendations -- it does not connect to the cluster or mount host, and does not apply any settings itself. All commands it outputs must be run manually (or scripted separately) against the cluster/agent.
* `-CpuCores` is only used for the Linux `grpc_number_of_default_cq` gflag; on AIX the two static, version-gated agent gflags (`JavaAgentGrpcThreadpoolSize`, `StorageProxyMaxBrickReadSize`) are not currently derived from `-CpuCores`.
