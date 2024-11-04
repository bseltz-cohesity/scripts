# Backup Database Logs using Bash

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script performs a runNow on a protection job, specifying the log backup type.

This script was written to run on AIX where a scripting language such as Python was unavailable.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/old/backupLogs/backupLogs.sh
chmod +x backupLogs.sh
# end download commands
```

## Components

* backupLogs.sh: the bash script

## Dependencies

* curl: note that the version of curl must support TLS v1.2 to communicate with Cohesity
* sed: uses sed regular expressions to parse JSON responses

## Running the Script

Edit the top few lines of the file to match your environment:

```bash
cluster='mycluster'
username='myusername'
password='mypassword'
domain='mydomain.net'
jobname='My Job'
keeplocalfor=5
```

and then run the script like so:

```bash
bash:~/$ ./backupLogs.sh
running My Job (32392)...
```
