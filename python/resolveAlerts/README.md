# Resolve Alerts using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script script lists and resolves alerts

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/resolveAlerts/resolveAlerts.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x resolveAlerts.py
# end download commands
```

## Components

* [resolveAlerts.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/resolveAlerts/resolveAlerts.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./resolveAlerts.py -v mycluster \
                   -u myusername \
                   -d mydomain .net
```

To filter on a specific severity:

```bash
./resolveAlerts.py -v mycluster \
                   -u myusername \
                   -d mydomain .net \
                   -s kCritical
```

To filter on a specific alertType:

```bash
./resolveAlerts.py -v mycluster \
                   -u myusername \
                   -d mydomain .net \
                   -t 1007
```

add -resolution to any of the above to mark them resolved:

```bash
./resolveAlerts.py -v mycluster \
                   -u myusername \
                   -d mydomain .net \
                   -t 1007 \
                   -r 'We fixed this'
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -t, --alerttype: (optional) filter on alert type (e.g. 1007)
* -s, --severity: (optional) filter on severity (e.g. kCritical)
* -r, --resolution: (optional) mark s resolved with this text (report only if omitted)
