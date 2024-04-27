# Report Data Per Object using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script collects the logical size, data read and written over time of protected objects. Output is written to a CSV file.

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/dataPerObject/dataPerObject.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x dataPerObject.py
```

## Components

* dataPerObject.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./dataPerObject.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -b 31
#end example
```

## Parameters

* -v, --vip: Cohesity cluster to connect to
* -u, --username: Cohesity username
* -d, --domain: (optional) Active Directory domain (defaults to 'local')
* -n, --numruns: (optional) reduce if too much data is returned (default is 100)
* -b, --daysback: (optional) collect X days of data (default is 31)
* -x, --units: (optional) show values in GiB or MiB (default is GiB)
