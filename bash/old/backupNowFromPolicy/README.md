# Backup Now and Copy using Bash

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script performs a runNow on a protection job including replication and archiving to an external target. All retentions and targets are queried from the policy applied to the protection job.

This script was written to run on AIX where a scripting language such as Python was unavailable.

## Components

* backupNowFromPolicy.sh: the bash script

## Dependencies

* curl: note that the version of curl must support TLS v1.2 to communicate with Cohesity
* sed: uses sed regular expressions to parse JSON responses

The script runs like so:

```bash
bash:~/$ ./backupNowFromPolicy.sh
running My Job (6222)...
policyId 770535285385794:1544976774290:32789
keeping local snapshot for 3 days
replicating to anothercluster (698796861248052) for 6 days
archiving to S3 (3111) for 5 days
```
