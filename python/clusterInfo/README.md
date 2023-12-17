# Get Cluster and Node Information Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script collects cluster and node information and sends as an email attachment to specified users.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/clusterInfo/clusterInfo.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x clusterInfo.py
# end download commands
```

## Components

* [clusterInfo.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/clusterInfo/clusterInfo.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./clusterInfo.py -v mycluster \
                  -u myusername \
                  -d mydomain.net \
                  -pwd swordfish \
                  -t myuser@mydomain.net \
                  -t anotheruser@mydomain.net \
                  -s 192.168.1.95 \
                  -f backupreport@mydomain.net \
                  -l
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: password for authentication
* -l, --listgflags: list cluster gflags
* -s, --mailserver: SMTP gateway to forward email through
* -p, --mailport: (optional) defaults to 25
* -f, --sendfrom: email address to show in the from field
* -t, --sendto: email addresses to send report to (use repeatedly to add recipients)

## Output

The output will look something like this:

```text
------------------------------------
    Cluster Name: selab1.sre.cohesity.corp
      Cluster ID: 8649759331514673
  Healing Status: NORMAL
    Service Sync: True
Stopped Services: None
------------------------------------

  Chassis Name: NM156S015777
    Chassis ID: 1
      Hardware: C4000
Chassis Serial: NM156S015777

           Node ID: 14038005774621
           Node IP: 10.99.1.52
           IPMI IP: 10.99.1.32
           Slot No: 1
         Serial No: NM156S015777
     Product Model: C4605
        SW Version: 6.3.1c_release-20191209_84f6b398
            Uptime: up 4 weeks, 5 days, 23 hours, 31 minutes

           Node ID: 14038005774636
           Node IP: 10.99.1.53
           IPMI IP: 10.99.1.33
           Slot No: 2
         Serial No: NM156S015778
     Product Model: C4605
        SW Version: 6.3.1c_release-20191209_84f6b398
            Uptime: up 4 weeks, 5 days, 23 hours, 40 minutes

           Node ID: 14038005774641
           Node IP: 10.99.1.51
           IPMI IP: 10.99.1.31
           Slot No: 3
         Serial No: NM156S015796
     Product Model: C4605
        SW Version: 6.3.1c_release-20191209_84f6b398
            Uptime: up 4 weeks, 5 days, 23 hours, 21 minutes
```
