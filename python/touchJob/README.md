# Touch a Protection Job using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script simply gets and puts a protection job, the purpose being to change the ownership of the job.

## Components

* [touchJob.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/touchJob/touchJob.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/touchJob/touchJob.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x touchJob.py
# end download commands
```

Run the script like so:

```bash
./touchJob.py -v mycluster -u myuser -d local -j 'my job' 
```

To update multple jobs:

```bash
./touchJob.py -v mycluster -u myuser -d local -j 'my job1' -j 'my job2' 
```

Or provide a text file of job names (one per line):

```bash
./touchJob.py -v mycluster -u myuser -d local -l ./myjobs.txt 
```

To us an active directory account:

```bash
./touchJob.py -v mycluster -u myuser -d mydomain.net -j 'my job' 
```

To connect via helios:

```bash
./touchJob.py -u myuser@mydomain.net -c cluster1 -j 'my job'
# enter the API key as the password when prompted (see "Authenticating to Helios" below)
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

* -j, --jobname: (optional) job name to update (repeat for multiple)
* -l, --joblist: (optional) text file of job names to update (one per line)

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```
