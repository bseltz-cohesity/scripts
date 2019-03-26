# Backup Now and Copy using Bash

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script performs a runNow on a protection job including replication and archiving to an external target. All retentions and targets are explicitly defined in the settings section at the top of the script.

This script was written to run on AIX where a scripting language such as Python was unavailable.

## Components

* backupNowAndCopy.sh: the bash script

## Dependencies

* curl: note that the version of curl must support TLS v1.2 to communicate with Cohesity
* sed: uses sed regular expressions to parse JSON responses

The script runs like so:

```bash
bash:~/$ ./backupNowAndCopy.sh
replicating to anothercluster (698796861248052)
archiving to S3 (3111)
running My Job (32392)...
```
