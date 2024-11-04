# Backup Now a Disabled Job using Bash

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script unpauses a protection job, performs a runNow, waits for completion, re-pauses the job, and reports completion status.

This script was written to run on AIX where a scripting language such as Python was unavailable.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/old/backupNowDisabledJob/backupNowDisabledJob.sh
chmod +x backupNowDisabledJob.sh
# End download commands
```

## Components

* backupNowDisabledJob.sh: the bash script

## Dependencies

* curl: note that the version of curl must support TLS v1.2 to communicate with Cohesity
* sed: uses sed regular expressions to parse JSON responses

Edit the first few lines of the script to specify the cluster, username, password, etc, then run the script like so:

```bash
bash:~/$ ./backupNowDisabledJob.sh
running My Job (32392)...
Status: kSuccess
```
