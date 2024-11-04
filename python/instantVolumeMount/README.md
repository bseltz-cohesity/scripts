# Instant Volume Mount using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script performs an Instant Volume Mount recovery to a VM or physical server.

## Download The Scripts

Run the following commands to download the scripts:

```bash
# begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/instantVolumeMount/instantVolumeMount.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/instantVolumeMount/instantVolumeMountDestroy.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x instantVolumeMount.py
chmod +X instantVolumeMountDestroy.py
# end download commands
```

## Components

* [instantVolumeMount.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/instantVolumeMount/instantVolumeMount.py): the main python script
* [instantVolumeMountDestroy.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/instantVolumeMount/instantVolumeMountDestroy.py): script to tear down the mounted volume
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```bash
./instantVolumeMount.py -v mycluster \
                        -u myuser \
                        -d mydomain.net \
                        -s server1.mydomain.net \
                        -t server2.mydomain.net
```

To mount only a specific volume, use the -vol option, like so:

```bash
./instantVolumeMount.py -v mycluster \
                        -u myuser \
                        -d mydomain.net \
                        -s server1.mydomain.net \
                        -t server2.mydomain.net \
                        -m /C \
                        -m /D
```

To tear down the mount when finished:

```bash
./instantVolumeMountDestroy.py -v mycluster \
                               -u myuser \
                               -d mydomain.net \
                               -t 146112
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

* -s, --sourceserver: name of server that was backed up
* -t, --targetserver: (optional) name of server to restore to (default is sourceserver)
* -e, --environment: (optional) filter search by environemt type 'kPhysical', 'kVMware', 'kHyperV'
* -id, --id: (optional) filter search by object id
* -sh, --showversions: (optional) show available run IDs and snapshot dates
* -sv, --showvolumes: (optional) show available volumes
* -r, --runid: (optional) specify exact run ID
* -date, --date: (optional) use latest snapshot on or before date (e.g. '2023-10-21 23:00:00')
* -vol, --volumes: (optional) one or more volumes to mount (repreat for multiple))
* -w, --wait: (optional) wait and report completion status
* -debug, --debug: (optional) display JSON payload
* -x, --usearchive: (optional) pull volumes from cloud archive (will pull only from local snapshots if omitted)

## VM Parameters

* -vis, --hypervisor: (optional) vCenter, SCVMM, ESXi or HyperV instance to find target VM
* -a, --useexistingAgent: (optional) use existing Cohesity agent (VMware only)
* -vu, -vmusername: (optional) guest username to autodeploy Cohesity agent
* -vp, vmpassword: (optional) guest passwprd to autodeploy Cohesity agent

## Other Parameters for instantVolumeMountDestroy

* -t, --taskid: task ID to tear down
