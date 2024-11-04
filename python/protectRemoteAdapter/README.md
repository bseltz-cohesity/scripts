# Protect Remote Adapter using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script creates or updates a remote adapter protection group

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectRemoteAdapter/protectRemoteAdapter.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectRemoteAdapter.py
# end download commands
```

## Components

* protectRemoteAdapter.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To display an existing protection group:

```bash
./protectRemoteAdapter.py -v mycluster \
                          -u myuser \
                          -d mydomain.net \
                          -j 'my job'
```

To create a new protection group:

```bash
./protectRemoteAdapter.py -v mycluster \
                          -u myuser \
                          -d mydomain.net \
                          -j 'my job' \
                          -p 'my policy' \
                          -vn myview
                          -sn server1.mydomain.net \
                          -su root \
                          -s /root/script.sh
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e --emailmfacode: (optional) send MFA code via email

## Basic Parameters

* -j, --jobname: name of the job to create or update
* -p, --policyname: (optional) name of policy (required when creating new job)
* -vn, --viewname: (optional) name of view to protect (required when creating new job)

## New Job Parameters

* -tz, --timezone: (optional) default is 'US/Eastern'
* -st, --starttime: (optional) default is '21:00'
* -is, --incrementalsla: (optional) default is 60 (minutes)
* -fs, --fullsla: (optional) default is 120 (minutes)
* -z, --pause: (optional) pause future runs

## Script Parameters

* -sn, --servername: (optional) Linux hostname or IP (required when creating new job)
* -su, --serveruser: (optional) Linux username (required when creating new job)
* -s, --script: (optional) path to script for incremental backup (required when creating new job)
* -ip, --scriptparams: (optional) parameters for incremental backup
* -l, --logscript: path to script for log backup (defaults to same as --script)
* -lp, --logparams: parameters for log backup (defaults to same as --scriptparams)
* -f, --fullscript: path to script for full backup (defaults to same as --script)
* -fp, --fullparams: parameters for full backup (defaults to same as --scriptparams)
