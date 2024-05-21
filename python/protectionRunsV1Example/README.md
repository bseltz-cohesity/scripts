# Protection Runs Example for Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script demonstrates how to gather protection runs using the v1 API in a scalable way.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectionRunsV1Example/protectionRunsV1Example.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectionRunsV1Example.py
# end download commands
```

## Components

* [protectionRunsV1Example.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectionRunsV1Example/protectionRunsV1Example.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectionRunsV1Example.py -v mycluster \
                             -u myuser \
                             -d mydomain.net
```

To connect via Helios:

```bash
./protectionRunsV1Example.py -c mycluster \
                             -u myuser@mydomain.net
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
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: (optional) name of the job to include (repeat for multiple)
* -l, --joblist: (optional) text file of job names to include (one per line)
* -n, --numruns: (optional) number of runs to retrieve per API call (default is 1000)
* -y, --daysback: (optional) number of days back to look (default is back to cluster creation)
