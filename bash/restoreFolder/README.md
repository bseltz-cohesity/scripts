# Restore a Folder using Bash

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script performs a restore of a folder from one physical server to another.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/restoreFolder/restoreFolder.sh
chmod +x restoreFolder.sh
# End download commands
```

## Components

* restoreFolder.sh: the bash script

## Dependencies

* curl: note that the version of curl must support TLS v1.2 to communicate with Cohesity
* jq: uses jq to parse JSON responses

Edit the first few lines of the script to specify the cluster, username, password, etc, then run the script like so:

```bash
bash:~/$ ./restoreFolder.sh
connecting to mycluster...
waiting for existing job runs to finish...
performing restore...
Restore completed with status: kSuccess
```
