# Get List of Active Replication Tasks using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script lists the currently running replication tasks, from oldest to newest.

## Components

* [replicationQueue.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/replicationQueue/replicationQueue.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/replicationQueue/replicationQueue.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x replicationQueue.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./replicationQueue.py -v mycluster -u myuser -d mydomain.net
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

* -t, --olderthan: (optional) review only runs that are older than X days
* -y, --youngerthan: (optional) review only runs that are younger than X days
* -o, --canceloutdated: (optional) cancel replications that are already due to expire
* -a, --cancelall: (optional) cancel all replications
* -j, --jobname: (optional) job name to check (repeat for multiple)
* -l, --joblist: (optional) text file of job names to check (one per line)
* -r, --remotecluster: (optional) only show/cancel for thiis remote cluster only
* -n, --numRuns: (optional) number of runs per job to inspect (default is 9999)
* -k, --daystokeep: (optional) show as outdated if original backup time is older than X days ago
* -f, --showfinished: (optional) show finished replications
* -x, --units: (optional) display bytes as MiB or GiB (default is MiB)

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

Please see here for more information: <https://github.com/cohesity/community-automation-samples/tree/main/python#cohesity-rest-api-python-examples>
