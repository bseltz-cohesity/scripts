# Protect a Cohesity View using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script protects a Cohesity View.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectView/protectView.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectView.py
# end download commands
```

## Components

* [protectView.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectView/protectView.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectView.py -v mycluster \
                 -u myusername \
                 -d mydomain.net \
                 -j 'my view backup' \
                 -n myview1 \
                 -p 'my policy'
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multitenancy org name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Basic Job Parameters

* -n, --viewname: name of view to protect (repeat for multiple views)
* -l, --viewlist: text file of views to protect (one per line)
* -j, --jobname: Name of protection group to create or update

## Optional Job Parameters

* -p, --policyname: Name of protection policy to use
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -z, --pause: (optional) pause future runs of new job
* -di, --disableindexing: (optional) do not index
* -prefix, --drprefix: (optional) prefix for remote view name
* -suffix, --drsuffix: (optional) suffix for remote view name
* -ct, --clienttype: (optional) Generic or SBT (default is Generic)
* -cv, --catalogview: (optional) name of catalog view
