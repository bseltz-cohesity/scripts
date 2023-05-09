# Backup Now One Object using Bash

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script performs a run now on a protection job, selecting one object.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/bash/backupNowOneObject/backupNowOneObject.sh
chmod +x backupNowOneObject.sh
# End download commands
```

## Components

* backupNowOneObject.sh: the bash script

## Dependencies

* curl: note that the version of curl must support TLS v1.2 to communicate with Cohesity

Edit the first few lines of the script to specify the cluster, username, password, etc:

```bash
cluster='thiscluster'  # name or IP of Cohesity cluster to connect to
username='myusername'  # username to connect to Coheity cluster
password='mypassword'  # password to connect to Cohedity cluster
domain='local'         # domain of user e.g. local or mydomain.net
jobid=74120            # v1 job ID of protection job
sourceid=72            # source ID of protection source

# replication
remotecluster='anothercluster'   # name of remote cluster to replicate to
remoteclusterid=428418101664119  # cluster ID of remote cluster to replicate to
keepreplicafor=7                 # days to retain replica

# archive
archivetarget='Minio'     # name of archive target
archivetargetid=1036695   # ID of archive target
keeparchivefor=31         # days to retain archive
```

If replication and archiving is not required you can remove those sections (and remove the associated copyTargets from the JSON payload at the end of the file).

Then run the script like so:

```bash
bash:~/$ ./backuNowOneObject.sh
```
