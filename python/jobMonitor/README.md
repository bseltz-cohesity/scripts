# Monitor Protection Jobs using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script monitors the status and progress of protection jobs.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/jobMonitor/jobMonitor.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x jobMonitor.py
# end download commands
```

## Components

* [jobMonitor.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/jobMonitor/jobMonitor.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To display the status of all jobs:

```bash
./jobMonitor.py -v mycluster \
                -u myusername \
                -d mydomain.net
```

To display the status of one or more specific jobs:

```bash
./jobMonitor.py -v mycluster \
                -u myusername \
                -d mydomain.net \
                -j 'my job 1' \
                -j 'my job 2'
```

To display the status including objects within the jobs:

```bash
./jobMonitor.py -v mycluster \
                -u myusername \
                -d mydomain.net \
                -j 'my job 1' \
                -j 'my job 2' \
                -s
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: (optional) name of job to display (repeat parameter for multiple jobs)
* -s, --showobjects: (optional) show percent complete for running objects within the jobs
* -n, --numruns: (optional) dig through X runs to find running jobs (default is 10)
