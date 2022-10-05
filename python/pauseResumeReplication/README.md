# Pause or Resume Replication using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script pauses or resumes replication.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pauseResumeReplication/pauseResumeReplication.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x pauseResumeReplication.py
# end download commands
```

## Components

* pauseResumeReplication.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To pause all outbound replication from a cluster:

```bash
./pauseResumeReplication.py -v mycluster \
                            -u myusername \
                            -d mydomain.net \
                            -p
```

To pause replication to a specific cluster:

```bash
./pauseResumeReplication.py -v mycluster \
                            -u myusername \
                            -d mydomain.net \
                            -n cluster2 \
                            -p
```

To resume replication:

```bash
./pauseResumeReplication.py -v mycluster \
                            -u myusername \
                            -d mydomain.net \
                            -r
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password of API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --remoteclustername: (optional) name of a remote cluster (repeat for multiple)
* -l, --remoteclusrterlist: (optional) text file of remote clusters (one per line)
* -p, --pause: (optional) pause replication
* -r, --resume: (optional) resume replication
