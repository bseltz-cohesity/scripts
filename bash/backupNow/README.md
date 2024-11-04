# Backup Now using Bash

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script runs a protection job. It will use the policy settings to include replication and archive copies. Note that the base retention is used (extended retentions are not applied). For physical server backups, you can optionally specify one server to backup (otherwise all servers are backed up). The script supports API key authentication only.

## Dependencies

This script requires `curl` and `jq` and has been tested on:

* Fedora 35
* CentOS 7
* AIX 7.3
* MacOS Ventura

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/backupNow/backupNow.sh
chmod +x backupNow.sh
# End download commands
```

## Parameters

* -v: cluster vip or endpoint to connect to
* -j: name of protection job to run
* -k: api key for authentication
* -o: (optional) name of server to backup (for physical protection groups only)
* -s: (optional) sleep time between status updates, in seconds (default is 60)

## Example

```bash
# example
./backupNow.sh -v mycluster -j 'my job' -k 1e62583e-4216-45fc-6377-d56e2c5c3776
# end example
```

or to backup a single server within the job:

```bash
# example
./backupNow.sh -v mycluster -j 'my job' -k 1e62583e-4216-45fc-6377-d56e2c5c3776 -o server1.mydomain.net
# end example
```
