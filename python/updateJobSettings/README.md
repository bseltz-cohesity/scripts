# Update Common Protection Group Settings using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script updates various common protection group settings, including:

* policy assignment
* start time
* time zone
* SLA settings
* pause / resume

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/updateJobSettings/updateJobSettings.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x updateJobSettings.py
# end download commands
```

## Components

* [updateJobSettings.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/updateJobSettings/updateJobSettings.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example - change the policy for two jobs
./updateJobSettings.py -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -j 'My Job1' \
                       -j 'My Job2' \
                       -np 'New Policy'

# example - change the incrental SLA for a list of jobs
./updateJobSettings.py -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -l joblist.txt \
                       -is 90

# example - pause all jobs
./updateJobSettings.py -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -z

# example - resume all jobs
./updateJobSettings.py -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -r

# end examples
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) impersonate tenant
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -n, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication

## Filter Parameters

* -p, --policyname: (optional) select jobs to updatee that currently use this policy name
* -j, --jobname: (optional) name of job to update (repeat for multiple)
* -l, --joblist: (optional) text file of job names to update (one per line)

## Update Parameters

* -np, --newpolicyname: (optional) update jobs to use this policy name
* -tz, --timezone: (optional) time zone (e.g. 'US/Eastern')
* -st, --starttime: (optional) start time (e.g. is '21:00')
* -is, --incrementalsla: (optional) incremental SLA minutes
* -fs, --fullsla: (optional) full SLA minutes
* -z, --pause: (optional) pause the job(s)
* -r, --resume: (optional) resume the job(s)
* -q, --noquiesce: (optional) disable app/crash consistent setting
* -a, --alertonslaviolation: (optional) enable alert for SLA violation
* -ei, --enableindexing: (optional) enable indexing (applies default indexing policy)
* -di, --disableindexing: (optional) disable indexing
* -ai, --addincludepath: (optional) include indexing paths (specified by --indexpath and --indexlist)
* -ae, --addexcludepath: (optional) exclude indexing paths (specified by --indexpath and --indexlist)
* -ri, --removeincludepath: (optional) remove included indexing paths (specified by --indexpath and --indexlist)
* -re, --removeexcludepath: (optional) remove excluded indexing paths (specified by --indexpath and --indexlist)
* -ip, --indexpath: (optional) path to add/remove from included/excluded indexing paths (repeat for multiple)
* -il, --indexlist: (optional)) text file of paths to add/remove from included/excluded indexing paths (one per line)
* -ce, --clearexcludepaths: (optional) remove all indexing exclusions
