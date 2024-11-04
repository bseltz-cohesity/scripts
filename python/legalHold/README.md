# Add or Remove Legal Hold using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script add or removes legal hold from a specified backup on the cluster.

## Components

* [legalHold.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/legalHold/legalHold.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/legalHold/legalHold.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x legalHold.py
# end download commands
```

List available protection runs (run ID, run date and hold status):

```bash
./legalHold.py -v mycluster -u myuser -j 'my job'
```

To add legal hold to a specific run (by run ID):

```bash
./legalHold.py -v mycluster -u myuser -j 'my job' -id 34567 -a
```

To remove legal hold from a specific run (by run date):

```bash
./legalHold.py -v mycluster -u myuser -j 'my job' -dt '2024-01-04 01:00' -r
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -j, --jobname: protection job name
* -id, --runid: (optional) run ID to operate on
* -rl, --runidlist: (optional) text file containing run IDs (one per line)
* -dt, --rundate: (optional) run date to operate on (e.g. '2024-01-03 23:30')
* -a, --addhold: (optional) add legal holds
* -r, --removehold: (optional) remove legal holds
* -p, --pushtoreplicas: (optional) push legal hold adds/removes to replicas
* -l, --includelogs: (optional) include log backups
* -y, --daysback: (optional) include runs from only the last X days
* -n, --numruns: (optional) runs per api query (default is 1000)
