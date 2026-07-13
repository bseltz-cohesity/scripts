# EPIC Cache/IRIS gFlag Tuning Script

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script calculates recommended Cohesity cluster and agent gflag settings for tuning EPIC Cache/IRIS (operational database) backup performance on physical Linux or AIX mount hosts. Given a handful of inputs about the cluster and mount host, it prints the recommended settings to the screen and writes them - along with ready-to-paste commands and instructions to apply them - to a text file.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/epicGflagRecommendations/epicGflagRecommendations.sh
chmod +x epicGflagRecommendations.sh
# End download commands
```

## Usage

```bash
./epicGflagRecommendations.sh -n <count> -o <AIX|LINUX> [options]
```

| Short | Long             | Required | Description                                                                                          |
|-------|------------------|----------|--------------------------------------------------------------------------------------------------------|
| `-n`  | `--node-count`     | Yes      | Number of nodes in the Cohesity cluster (1-256).                                                       |
| `-o`  | `--host-os`        | Yes      | Operating system of the EPIC mount host: `AIX` or `LINUX`.                                             |
| `-s`  | `--nic-speed`      | No       | Mount host NIC speed range: `10GbE` or `>10GbE`. Default: `>10GbE`.                                     |
| `-c`  | `--cpu-cores`      | No       | Number of CPU cores on the mount host (1-1024), e.g. 2 x Intel Xeon 12-core = 24. Default: `24`.        |
| `-a`  | `--agent-endpoint` | No       | Hostname or IP of the mount host, substituted into the agent CLI commands. Default: a placeholder you can fill in later. |
| `-f`  | `--output-file`    | No       | Path to the text file the recommendations are written to. Default: `./EpicGflagRecommendations.txt`.   |
| `-h`  | `--help`           | No       | Show usage and exit.                                                                                    |

## Examples

Simple syntax:

```bash
./epicGflagRecommendations.sh -n 8 -o AIX
```

AIX mount host, 19-node cluster, 10GbE NIC, 20 CPU cores:

```bash
./epicGflagRecommendations.sh -n 19 -o AIX -s 10GbE -c 20
```

Linux mount host, 8-node cluster, faster NIC, known agent hostname, custom output path:

```bash
./epicGflagRecommendations.sh -n 8 -o LINUX -s ">10GbE" -c 32 \
    -a epic-mount01.hospital.local -f /tmp/epic01-gflags.txt
```

## What the output file contains

* **Recommended Settings** - every applicable gflag, its recommended and default value, and the command to set it.
* **Cluster iris_cli Commands (paste-ready)** - the cluster-level commands with the leading `iris_cli` stripped off, ready to paste into an already-open `iris_cli` session.
* **Agent magneto_agent_debug_tool Commands (paste-ready)** - the agent-level commands, run from an SSH session on the Cohesity cluster.
* **Agent Config File Stanza** - the same agent gflags as a `user_settings { gflag_setting_vec { ... } }` block, for editing the agent config file directly instead of using `magneto_agent_debug_tool`.
* **env.sh Settings** (AIX only) - the two `/usr/local/cohesity/set_env.sh` values to update.
* **Restarting the Cohesity Agent** - the commands to restart the agent after applying config file or env.sh changes.

## Applying the settings

Cluster-level gflags are applied with `iris_cli`, run from any CVM or via SSH to the cluster VIP.

Agent-level gflags are applied with `magneto_agent_debug_tool`, run from an SSH session on the Cohesity cluster - not on the mount host. As an alternative, the agent config file (`/etc/aix_agent_config.cfg` on AIX, `/etc/cohesity-agent/agent.cfg` on Linux) can be edited directly using the stanza in the output file; merge it into any existing `user_settings` block rather than adding a second one.

On AIX, the two `set_env.sh` values already exist in the file and just need their values updated.

After making any config file or `set_env.sh` change, restart the Cohesity agent using the commands in the output file, then kick off a test backup and monitor throughput before rolling out further.
