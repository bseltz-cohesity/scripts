# Throttle Replication using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script adds/removes replication throttles.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/throttleReplication/throttleReplication.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x throttleReplication.py
# end download commands
```

## Components

* [throttleReplication.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/throttleReplication/throttleReplication.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To block all outbound replication from a cluster:

```bash
./throttleReplication.py -v mycluster \
                         -u myusername \
                         -d mydomain.net \
                         -block
```

To block replication to a specific cluster:

```bash
./throttleReplication.py -v mycluster \
                         -u myusername \
                         -d mydomain.net \
                         -n cluster2 \
                         -block
```

To resume replication:

```bash
./throttleReplication.py -v mycluster \
                         -u myusername \
                         -d mydomain.net \
                         -clear
```

To define a quiet period with a bandwidth limit of 10 Mpbs on weekdays from 9am to 5pm:

```bash
./throttleReplication.py -v mycluster \
                         -u myusername \
                         -d mydomain.net \
                         -b 10 \
                         -w \
                         -st '09:00' \
                         -et '17:00'
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
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --remoteclustername: (optional) name of a remote cluster (repeat for multiple)
* -l, --remoteclusrterlist: (optional) text file of remote clusters (one per line)
* -ru, --remoteusername: (optional) name of user to authenticate replication
* -rp, --remotepassword: (optional) password of user to authenticate replication
* -pp, --promotforremotepassword: (optional) prompt for password of user to authenticate replication
* -block, --block: (optional) block replication
* -clear, --clear: (optional) unblock replication, remove all throttles and quiet periods
* -limit, --limit: (optional) set a full time hard limit
* -b, --bandwidth: (optional) default is 0 Mbps
* -e, --everyday: (optional) set quiet period to every day
* -w, --weekdays: (optional) set quiet period to weekdays
* -sun, --sunday: (optional) set quiet period to include Sunday
* -mon, --monday: (optional) set quiet period to include Monday
* -tue, --tuesday: (optional) set quiet period to include Tuesday
* -wed, --wednesday: (optional) set quiet period to include Wednesday
* -thu, --thursday: (optional) set quiet period to include Thursday
* -fri, --friday: (optional) set quiet period to include Friday
* -sat, --saturday: (optional) set quiet period to include Saturday
* -st, --starttime: (optional) set quiet period start time (default is '09:00')
* -et, --endtime: (optional) set quiet period end time (default is '17:00')
* -tz, --timezone: (optional) default is 'US/Eastern'
