# Get Cluster VIPs by Least Busy CPU

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script gets a list of cluster VIPs sorted by CPU usage

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/vipsLeastBusy/vipsLeastBusy.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x vipsLeastBusy.py
# end download commands
```

## Components

* [vipsLeastBusy.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/vipsLeastBusy/vipsLeastBusy.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./vipsLeastBusy.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -n 4
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -n, --nodecount: (optional) default is 4
* -l, --vlanid: (optional) default is 0

## Notes

The selected VLAN must be reachable by the script in order to query the nodes. If the VLAN is not reachable, the script will timeout and fail.
