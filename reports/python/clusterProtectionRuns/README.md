# Generate Protection Runs Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script lists the active snapshot count for every protected object in Cohesity.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/clusterProtectionRuns/clusterProtectionRuns.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x clusterProtectionRuns.py
# end download commands
```

## Components

* clusterProtectionRuns.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./clusterProtectionRuns.py -v mycluster -u myusername -d mydomain.net
# end example
```

Or via Helios

```bash
# example
./clusterProtectionRuns.py -u myusername
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

* -y, --days: (optional) days back to search
* -x, --unit: (optional) KiB, MiB, GiB, or TiB] (default is GiB)
* -t, --objecttype: (optional) filter by type (e.g. kSQL)
* -l, --includelogs: (optional) include log runs
* -n, --numruns: (optional) number of runs per API query (default is 500)
* -o, --outputpath: (optional) default is '.'
* -f, --outputfile: (optional) default is protectionRunsReport-date.tsv
* -on, --objectname: (optional) name of server/view to include in report (repeat for multiple)
* -ol, --objectlist: (optional) text file of servers/views to include in report (one per line)
