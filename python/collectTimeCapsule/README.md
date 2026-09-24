# Collect a Timecapsule Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script collects a Cohesity Timecapsule (support bundle), then downloads it locally.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/collectTimeCapsule/collectTimeCapsule.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py
chmod +x collectTimeCapsule.py
# end download commands
```

## Components

* [collectTimeCapsule.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/collectTimeCapsule/collectTimeCapsule.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./collectTimeCapsule.py -v mycluster \
                        -u myusername \
                        -d mydomain.net \
                        -hb 24
```

## Basic Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to the Cohesity cluster
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) don't prompt for credentials if none are found/stored
* -m, --mfacode: (optional) MFA code
* -o, --outpath: (optional) local directory to downloaded to (defaults to the current directory)

## Collection Parameters

* -n, --nodeips: (optional) comma separated node IPs to collect from (defaults to all nodes)
* -s, --services: (optional) comma separated service names to collect logs for (defaults to all services)
* -ls, --listservices: (optional) print list of valid service names and exit
* -mt, --msgtypes: (optional) comma separated log message types to collect (default: INFO,WARNING,ERROR,FATAL)
* -c, --criticallogsonly: (optional) collect FATAL logs only
* -fd, --forcedelete: (optional) force delete old timecapsules
* -hb, --hoursback: (optional) collect logs from N hours ago until now, in UTC (default: 4; the cluster caps this at 48 hours)
* -od, --outputdir: (optional) directory on the cluster node(s) to write the bundle to (default: /home/cohesity/data/timecapsules)

## Advanced Options

* -pi, --pollintervalsecs: (optional) seconds between polls while waiting for the bundle to appear and finish writing (default: 15)
* -pw, --pollwaitmins: (optional) minutes to wait for the collection to finish before giving up (default: 30)
* -debug, --debug: (optional) print the full request URL before submitting it, and the HTTP status/byte count of the response

## Examples

Collect the last 4 hours of logs from every node/service, using defaults:

```bash
./collectTimeCapsule.py -v mycluster -u myusername -d mydomain.net
```

Collect the last 24 hours, deleting any existing Timecapsule directory content on the node(s) first:

```bash
./collectTimeCapsule.py -v mycluster -u myusername -d mydomain.net -hb 24 -fd
```

Collect from specific nodes and services only:

```bash
./collectTimeCapsule.py -v mycluster -u myusername -d mydomain.net \
                -n 10.1.1.10,10.1.1.11 -s apollo,stargate,bridge
```

Collect FATAL-only critical logs:

```bash
./collectTimeCapsule.py -v mycluster -u myusername -d mydomain.net -c
```

List the service names Siren considers valid for a cluster without collecting anything:

```bash
./collectTimeCapsule.py -v mycluster -u myusername -d mydomain.net -ls
```

Troubleshoot a request that doesn't seem to be doing anything, by seeing exactly what's being sent:

```bash
./collectTimeCapsule.py -v mycluster -u myusername -d mydomain.net -hb 24 -debug
```
