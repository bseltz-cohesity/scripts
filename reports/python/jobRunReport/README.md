# Display Job Status Last 24 Hours using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script reports the status of the last job run of each protection job for the past 24 hours.

## Components

* jobRunReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/jobRunReport/jobRunReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x jobRunReport.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./jobRunReport.py -v mycluster -u myusername -d mydomain.net
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd: --password: (optional) use password from command line instead of stored password
* -l, --localonly: (optional) only report local jobs (omit replicated jobs)

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
