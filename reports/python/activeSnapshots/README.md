# List Active Snapshot Counts Per Protected Object

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script lists the active snapshot count for every protected object in Cohesity.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/activeSnapshots/activeSnapshots.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x activeSnapshots.py
# end download commands
```

## Components

* activeSnapshots.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./activeSnapshots.py -v mycluster -u myusername -d mydomain.net
# end example
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

* -n, --pagesize: (optional) page size for API query (default is 100)
* -y, --days: (optional) limit query to the past X days
* -e, --environment: (optional) limit query to specific types (e.g. kSQL) repeat for multiple
* -x, --excludeenvironment: (optional) exclude types (e.g. kSQL) repeat for multiple
* -o, --outputpath: (optional) default is '.'
* -l, --localonly: (optional) include only local jobs (no replicas)

## Email Parameters

* -ms, --mailserver: (optional) SMTP gateway to send mail to
* -mp, --mailport: (optional) SMTP port (default is 25)
* -to, --sendto: (optional) email address to send to (repeat for multiple)
* -fr, --sendfrom: (optional) email address to send from
