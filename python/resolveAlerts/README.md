# Resolve Alerts using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script lists and resolves open alerts, either directly on a Cohesity cluster or through Helios. When resolving, it reuses an existing resolution with the same name if one exists, otherwise it creates a new one.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/resolveAlerts/resolveAlerts.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py
chmod +x resolveAlerts.py
# end download commands
```

## Components

* [resolveAlerts.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/resolveAlerts/resolveAlerts.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# connect directly to a cluster
./resolveAlerts.py -v mycluster \
                   -u myusername \
                   -d mydomain.net

# connect to Helios (all clusters)
./resolveAlerts.py -v helios.cohesity.com \
                   -u myusername

# connect to Helios and select one cluster
./resolveAlerts.py -v helios.cohesity.com \
                   -u myusername \
                   -c mycluster
```

To filter on a specific severity:

```bash
./resolveAlerts.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -s kCritical
```

To filter on a specific alert type:

```bash
./resolveAlerts.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -at 1007
```

To filter on alerts from the last 7 days whose description matches a pattern:

```bash
./resolveAlerts.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -md 7 \
                   -ms 'protection group'
```

Add `-r` to any of the above to mark the matching alerts resolved:

```bash
./resolveAlerts.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -at 1007 \
                   -r 'We fixed this'
```

## Output

The matching alerts are listed on screen and written to `alerts.csv` in the current folder (newest first). When connected to Helios without `-c`, a Cluster column is included.

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster or MCM to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity (default is helios)
* -d, --domain: (optional) domain of username (default is local)
* -t, --tenant: (optional) organization to impersonate
* -c, --clustername: (optional) Helios/MCM cluster to connect to (if omitted when connected to Helios/MCM, alerts from all clusters are processed)
* -mcm, --mcm: (optional) connect through MCM instead of directly to the cluster
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key (not recommended, use stored passwords where possible)
* -np, --noprompt: (optional) do not prompt for password
* -m, --mfacode: (optional) TOTP MFA code
* -e, --emailmfacode: (optional) send MFA code via email
* -region, --region: (optional) specify region ID for Helios (DMaaS)

## Filter Parameters

* -at, --alerttype: (optional) filter on alert type (e.g. 1007)
* -ac, --alertcode: (optional) filter on alert code
* -ai, --alertid: (optional) filter on alert ID
* -s, --severity: (optional) filter on severity (e.g. kCritical)
* -sn, --systemname: (optional) filter on cluster name (useful when connected to Helios)
* -ms, --matchstring: (optional) filter on alert descriptions matching this regular expression (case-insensitive)
* -sd, --startdate: (optional) only alerts on or after this date (`YYYY-MM-DD` or `YYYY-MM-DD HH:MM:SS`)
* -ed, --enddate: (optional) only alerts on or before this date (`YYYY-MM-DD` or `YYYY-MM-DD HH:MM:SS`)
* -md, --maxdays: (optional) only alerts from the last this-many days
* -sbd, --sortbydescription: (optional) sort the listing by description instead of time

## Resolution Parameters

* -r, --resolution: (optional) mark alerts resolved with this text (report only if omitted). If a resolution with this name already exists, it is reused; otherwise a new one is created.

## Notes

When connected to Helios without `-c`, alerts are retrieved from all connected clusters and resolved through Helios, and then resolved again directly on each affected cluster.
