# Add or Remove Legal Hold Per Object using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script add or removes legal hold to the specified objects.

## Components

* [legalHoldObject.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/legalHoldObject/legalHoldObject.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/legalHoldObject/legalHoldObject.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x legalHoldObject.py
# end download commands
```

Show if legal hold is on:

```bash
./legalHoldObject.py -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -jn 'my job' \
                     -on 'myobject1' \
                     -on 'myobject2' \
                     -st
```

Show if legal hold is off:

```bash
./legalHoldObject.py -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -jn 'my job' \
                     -on 'myobject1' \
                     -on 'myobject2' \
                     -sf
```

Set legal hold

```bash
./legalHoldObject.py -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -jn 'my job' \
                     -on 'myobject1' \
                     -on 'myobject2' \
                     -a
```

Remove legal hold

```bash
./legalHoldObject.py -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -jn 'my job' \
                     -on 'myobject1' \
                     -on 'myobject2' \
                     -r
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

## Selection Parameters

* -jn, --jobname: (optional) one or more protection jobs to include (repeat for multiple)
* -jl, --joblist: (optional) text file of job names to include (one per line)
* -on, --objectname: (optional) one or more object names to include (repeat for multiple)
* -ol, --objectlist: (optional) text file of object names to include (one per line)

## Action Parameters

* -a, --addhold: (optional) add legal holds
* -r, --removehold: (optional) remove legal holds
* -st, --showtrue: (optional) show if legal hold is set
* -sf, --showfalse: (optional) show if legal hold is not set

## Filter Parameters

* -l, --includelogs: (optional) include log backups
* -y, --daysback: (optional) include runs from only the last X days
* -s, --startdate: (optional) include runs only after this date (e.g. '2024-11-01 00:00:00')
* -e, --enddate: (optional) include runs only before this date (e.g. '2024-12-01 00:00:00')
