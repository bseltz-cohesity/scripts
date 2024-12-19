# Report Replication Stats using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script generates a report of replication stats, per object, per run, and per day.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/replicationReport/replicationReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x replicationReport.py
# end download commands
```

## Components

* replicationReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./replicationReport.py -v mycluster -u myusername -d mydomain.net
# end example
```

## Authentication Parameters

* -v, --vip: one or more DNS or IP of the Cohesity cluster to connect to (repeat for multiple)
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to (repeat for multiple)
* -i, --useApiKey: (optional) use API Key authentication
* -pwd, --password: (optional) specify password or API key
* -np, --noprompt: (optional) do not prompt for password
* -m, --mfacode: (optional) mfa code (only works for one cluster)

## Other Parameters

* -j, --jobname: (optional) name of job to include (repeat for multiple)
* -l, --joblist: (optional) text file of job names to include (one per line)
* -n, --numruns: (optional) number of runs per API query (default is 100)
* -y, --days: (optional) number of days back to query (default is 7)
* -o, --outpath: (optional) path for output files (default is '.')
* -x, --units: (optional) MiB or GiB (default is GiB)
