# Get List of Active Archive Tasks using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script lists the currently running archive tasks, from oldest to newest.

## Components

* [archiveQueue.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/archiveQueue/archiveQueue.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/archiveQueue/archiveQueue.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x archiveQueue.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./archiveQueue.py -v mycluster -u myuser -d mydomain.net
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

* -o, --canceloutdated: (optional) cancel running archives that are past their intended expiration
* -q, --cancelqueued: (optional) cancel queued archives that have not started running
* -a, --cancellall: (optional) cancel all archive tasks
* -n, --numRuns: (optional) number of runs per job to inspect (default is 9999)
* -s, --units: (otional) MiB or GiB (default is MiB)

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

Please see here for more information: <https://github.com/cohesity/community-automation-samples/tree/main/python#cohesity-rest-api-python-examples>
