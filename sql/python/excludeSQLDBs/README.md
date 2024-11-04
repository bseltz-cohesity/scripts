# Exclude SQL DBs using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds or removes exclusions to SQL protection groups.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/python/excludeSQLDBs/excludeSQLDBs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x excludeSQLDBs.py
# end download commands
```

## Components

* excludeSQLDBs.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To list exclusions:

```bash
./excludeSQLDBs.py -v mycluster \
                   -u myuser \
                   -d mydomain.net
```

To add a regex exclusion:

```bash
./excludeSQLDBs.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -r 'sqlserver1.mydomain.net/.*/res.*'
```

Remove a regex exclusion:

```bash
./excludeSQLDBs.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -r 'sqlserver1.mydomain.net/.*/res.*' \
                   -remove
```

Clear all exclusions:

```bash
./excludeSQLDBs.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -clear
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
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: (optional) name of job to process (repeat for multiple)
* -jl, --joblist: (optional) text file of jobs to process (one per line)
* -f, --filter: (optional) non-regex filter to process (repeat for multiple)
* -fl, --filterlist: (optional) text file of non-regex filters to process (one per line)
* -r, --regex: (optional) regex filter to process (repeat for multiple)
* -rl, --regexlist: (optional) text file of regex filters to process (one per line)
* -clear, --clear: (optional) clear all exclusions
* -remove, --remove: (optional) clear specified exclusions
