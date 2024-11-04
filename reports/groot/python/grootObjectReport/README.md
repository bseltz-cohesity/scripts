# Groot Object Protection Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script collects the history of protection status for all protected objects over time.

## Components

* grootObjectReport: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/groot/python/grootObjectReport/grootObjectReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x logicalTrends.py
# end download commands
```

## Prerequisites

This python script requires two python modules (requests, psycopg2-binary) that are not present in the standard library. These can be installed in one of the following ways:

Using yum:

```bash
yum install python-requests python-psycopg2
```

Using pip:

```bash
pip install requests
pip install psycopg2-binary
```

Using easy_install:

```bash
easy_install requests
easy_install psycopg2-binary
```

## Running the script

Place both files in a folder together and run the main script like so:

```bash
./grootObjectReport.py -v mycluster -u myuser -d mydomain.net
```

The script will write an output file objectReport-mycluster.html, and optionally, send an html-formatted email

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (default is local)
* -s, --mailserver: (optional) smtp server to send mail through
* -p, --mailport: (optional) default is 25
* -t, --sendto: (optional) email recipient (repeat parameter to send to multiple recipients)
* -f, --sendfrom: (optional) email address for from field
* -n, --numdays: (optional) number of days back to report (default is 31)
