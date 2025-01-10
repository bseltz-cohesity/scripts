# Set Maintenance Mode on Protection Sources using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script starts or ends maintenance mode on protection sources.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/maintenance/maintenance.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x maintenance.py
# end download commands
```

## Components

* maintenance.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To start maintenance mode on a source:

```bash
./maintenance.py -v mycluster \
                 -u myuser \
                 -d mydomain.net \
                 -n mysource1.mydomain.net \
                 -n mysource2.mydomain.net \
                 -start
```

To schedule maintenance for a future date:

```bash
./maintenance.py -v mycluster \
                 -u myuser \
                 -d mydomain.net \
                 -n mysource1.mydomain.net \
                 -n mysource2.mydomain.net \
                 -starttime '2025-01-10 23:00:00' \
                 -endtime '2025-01-11 05:00:00`
```

To end maintenance mode on a source:

```bash
./maintenance.py -v mycluster \
                 -u myuser \
                 -d mydomain.net \
                 -n mysource1.mydomain.net \
                 -n mysource2.mydomain.net \
                 -end
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
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --sourcename: (optional) name of the source to manage (repeat for multiple)
* -l, --sourcelist: (optional) text file of source names to manage (one per line)
* -st, --starttime: (optional) time to start maintenance (e.g. '2025-01-10 23:00:00')
* -et, --endtime: (optional) time to end maintenance (e.g. '2025-01-11 05:00:00')
* -start, --startnow: (optional) start maintenance now
* -end, --endnow: (optional) end maintenance now
