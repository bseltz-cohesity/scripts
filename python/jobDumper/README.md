# Dump Protection Groups to JSON using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script script dumps the specified protection groups to JSON for analysis.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/jobDumper/jobDumper.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x jobDumper.py
# end download commands
```

## Components

* [jobDumper.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/jobDumper/jobDumper.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To dump a specific job:

```bash
# example
./jobDumper.py -v mycluster \
               -u myuser \
               -d mydomain.net \
               -j 'my job'
# end example
```

To dump all jobs of a specific type:

```bash
# example
./jobDumper.py -v mycluster \
               -u myuser \
               -d mydomain.net \
               -e kVMware
# end example
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

* -j, --jobname: (optional) one or more job names to include (repeat for multiple)
* -l, --joblist: (optional) text file of job names to cancel (one per line)
* -e, --environment: (optional) filter on jobs with this environment (e.g. kVMware)
* -s, --includesources: (optional) also dump related protection sources
