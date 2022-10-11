# Instant Volume Mount using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script performs an Instant Volume Mount recovery to a VM or physical server.

## Components

* instantVolumeMount.py: the main python script
* instantVolumeMountDestroy.py: script to tear down the mounted volume
* pyhesity.py: the Cohesity REST API helper module

## Download The Scripts

Run the following commands to download the scripts:

```bash
# begin download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/instantVolumeMount/instantVolumeMount.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/instantVolumeMount/instantVolumeMountDestroy.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x instantVolumeMount.py
chmod +X instantVolumeMountDestroy.py
# end download commands
```

Place the files in a folder together and run the main script like so:

```bash
./instantVolumeMount.py -v mycluster \
                        -u myuser \
                        -d mydomain.net \
                        -s server1.mydomain.net \
                        -t server2.mydomain.net \
                        -n 'mydomain.net\myuser' \
                        -p swordfish
```

The script output should be similar to the following:

```text
Connected!
mounting volumes to server2.mydomain.net...
Volume mount ended with status kSuccess
Task ID for tearDown is: 146112
C: mounted to F:\
lvol_1 mounted to E:\
```

To mount only a specific volume, use the -m option, like so:

```bash
./instantVolumeMount.py -v mycluster \
                        -u myuser \
                        -d mydomain.net \
                        -s server1.mydomain.net \
                        -t server2.mydomain.net \
                        -n 'mydomain.net\myuser' \
                        -p swordfish \
                        -m /C
                        -m /D
```

Note the volume naming convention, on Windows, mount points are entered as /C, /D, etc. In linux, mount points are entered like /, /opt/oracle, etc.

To tear down the mount when finished:

```bash
./instantVolumeMountDestroy.py -v bseltzve01 -u admin -t 146112
```

```text
Connected!
Tearing down mount points...
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

## Other Parameters for instantVolumeMount

* -s, --sourceserver: name of server that was backed up
* -t, --targetserver: (optional) name of server to restore to (default is sourceserver)
* -n, --targetusername: (optional) only required if agent is not already installed (VM)
* -p, --targetpassword: (optional) only required if agent is not already installed (VM)
* -a, --useexistingagent: (optional) use existing agent during mount to a VM
* -vol, --volume: (optional) specify volume name to mount (repeat for multiple volumes)
* -l, --showversions: show available versions
* -start, --start: show versions after date
* -end, --end: show versions before date
* -r, --runid: use specific run ID

## Other Parameters for instantVolumeMountDestroy

* -t, --taskid: task ID to tear down

## Notes

The same rules apply as when you are using the UI...

When targeting a VM, if the agent is not already present, you have to supply guest credentials (for VMtools to authenticate into the guest to instantiate the auto-deploy agent), using -n and -p parameters, like:

```bash
./instantVolumeMount.py -v mycluster -u myusername -s myvm -n root -p swordfish
```

Or if the agent is already installed in the VM, or if you're targeting a registered physical server, then you tell the script to use the existing agent using -a parameter, like:

```bash
./instantVolumeMount.py -v mycluster -u myusername -s myvm -a
```

It is strongly recommended that you try performing an IVM in the UI first so you can prove that it works, before trying with the script. Some reminders:

* IVM will not work for Linux VMs prior to Cohesity 6.4.1.
* Port 50051/TCP must be open inbound on the guest so the Cohesity cluster can reach the agent - this is true in every scenario (auto-deploy or pre-installed agent)
* Auto-deploy agent won't work if VMtools not present and healthy.
* Pre-installing the agent is more likely to succeed because it eliminates the gotchas for credentials and VMtools

## The Python Helper Module

The helper module, pyhesity.py, provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```

### Stored Passwords

There is no parameter to provide your password. The fist time you authenticate to a cluster, you will be prompted for your password. The password will be encrypted and stored in the user's home folder. The stored password will then be used automatically so that scripts can run unattended.

If your password changes, use apiauth with updatepw to prompt for the new password. Run python interactively and enter the following commands:

```python
from pyhesity import *
apiauth('mycluster', 'myuser', 'mydomain', updatepw=True)
```

If you don't want to store a password and want to be prompted to enter your password when you run your script, use prompt=True
