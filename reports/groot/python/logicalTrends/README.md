# Gather Logical Size of Protected Data using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script collects the logical size of data protected, over time, by environment type, and writes it to a CSV file, where, once brought into Excel, can be charted to analyze growth trends.

## Components

* logicalTrends.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/groot/logicalTrends/python/logicalTrends.py
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
./logicalTrends.py -v mycluster -u myuser -d mydomain.net
```

The script will write an output file logicalTrends-mycluster.csv. This file can be opened in Excel where a chart can be created to show the trends over time (I like the stacked area chart).

## Running the script on a Cohesity cluster

It isn't possible to install modules on the Cohesity cluster, so I have provided logicalTrends-Linux.zip which contains the missing modules.
