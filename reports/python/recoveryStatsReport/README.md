# Generate Recovery Stats Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a report of esitmated object size and data transferred durning recent recoveries.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/recoveryStatsReport/recoveryStatsReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x recoveryStatsReport.py
# end download commands
```

## Components

* recoveryStatsReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./recoveryStatsReport.py -v mycluster -u myusername -d mydomain.net
# end example
```

To report on multiple clusters:

```bash
# example
./recoveryStatsReport.py -v mycluster1 -v mycluster2 -u myusername -d mydomain.net
# end example
```

To connect through Helios:

```bash
# example
./recoveryStatsReport.py -u myuser@mydomain.net -c mycluster1 -c mycluster2
# end example
```

## Parameters

## Authentication Parameters

* -v, --vip: (optional) one or more names or IPa of Cohesity clustera to connect to (repeat for multiple) default is helios.cohesity.com
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) one or more helios/mcm clusters to connect to (repeat for multiple)
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -y, --daysback: (optional) include recoveries from the last X days (default is 7)
* -of, --outfolder: (optional) where to write report html (default is current directory)
* -f, --outfilename: (optional) default is recoveryStatsReport.csv
* -x, --unit: (optional) KiB, MiB or GiB (default is GiB)
