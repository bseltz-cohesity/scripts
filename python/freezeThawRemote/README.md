# Use Remote Python Host in Freeze/Thaw Process for Volume Backups

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This example shows how to use a remote Python host to enable API driven triggering of freeze/thaw scripts on hosts (like AIX) where a viable scripting language may not be available.

## Components for AIX Host

* [freeze.sh](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/freezeThawRemote/freeze.sh): contains host freeze commands, placed on the AIX host
* [thaw.sh](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/freezeThawRemote/thaw.sh): contains host thaw commands, placed on the AIX host
* [waitforsnaps.sh](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/freezeThawRemote/waitforsnaps.sh): calls remote python script

## Components for Remote Python Host

* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module, placed on a remote python host
* [monitorTasks.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/freezeThawRemote/monitorTasks.py): monitors for task status during the host/volume backup, placed on a remote python host
* [storePassword.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/freezeThawRemote/storePassword.py): helps you set stored passwords for unattended API access

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/freezeThawRemote/freeze.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/freezeThawRemote/thaw.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/freezeThawRemote/waitforsnaps.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/freezeThawRemote/monitorTasks.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/freezeThawRemote/storePassword.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
# end download commands
```

## Workflow

* Cohesity will call the freeze.sh script on the AIX host (as defined in the pre-script settings of the protection job).
* The freeze.sh script on the AIX host will freeze the host/app and then spawn the waitforsnaps.sh script in the background, allowing freeze.sh to end.
* The waitforsnaps.sh script will remotely start the monitorTasks.py script on the Python host.
* The monitorTasks.py script will watch the protectionJob progress until the KEYSTRING is detected on all objects (volumes) in the protection job, indicating that all volume snapshots have been created. The script will call back the AIX host and launch the thaw.sh at this point, or after TIMEOUTSEC is reached.
* The thaw.sh script on the AIX host will thaw the host/app. This will occur while the snaphot copy phase of the backup continues, allowing the host/app to resume long before the backup is complete.

## On the AIX Host

Copy freeze.sh, thaw.sh, and waitforsnaps.sh to the AIX host. Make sure to set these scripts as executable (chmod +x *.sh), and then:

* Edit the freeze.sh script to include any freeze commands appropriate to your host/application.
* Edit the thaw script to include any thaw commands appropriate to your application.
* Edit the waitforsnaps.sh to set all options:

```bash
# python monitoring script location (remote python host)
SCRIPT_LOCATION=someuser@192.168.1.195
SCRIPT_FILE=./monitorTasks.py

# freeze/thaw script location (AIX host)
SCRIPT_CALLBACK=someuser@192.168.1.191
CALLBACK_FILE=./thaw.sh

# Cohesity info
COHESITY_CLUSTER=cluster1
COHESITY_USER=admin

# python script parameters
TIMEOUTSEC=120
MAIL_SERVER=192.168.1.95
SENDTO=me@mydomain.net
SENDFROM=somehost@mydomain.net
KEYSTRING='Getting mapped/changed areas for volume' # pure
# KEYSTRING='Starting directory differ' # netapp
```

The KEYSTRING contains the text in the backup log that we're checking for that occurs after the volume snapshot has been completed. This is different depending on the storage provider (e.g. Pure, NetApp).

## On the Remote Python Host

Copy the pyhesity.py, monitorTasks.py and storePassword.py files to the remote Python host. Make sure to set these files as executable (chmod +x *.py). 

This host should be modern Linux, new enough to support TLS1.2 and Python 2.7.x or later. One python module, requests, is required to be installed (all other python dependencies are part of the python standard library).

You can use the storePassword.py to store the API password to access Cohesity, like so:

```bash
./storePassword.py -v mycluster -u myusername -d mydomain.net
```

## On Cohesity

In the protection job/group on Cohesity, configure the job to use the freeze.sh script on the AIX host as the pre-script.

## SSH Interactions

There are three ssh connections that will occur during the process, for which we need to copy ssh keys so that passwordless ssh sessions can occur:

* Cohesity to AIX Host: copy the Cohesity user ssh key to the authorized keys for the user on the AIX host
* AIX Host to Python Host: copy the AIX user ssh key to the authorize keys for the user on the Python host
* Python Host to AIX Host: copy the Python host user ssh key to the authorized keys for the user on the AIX host

## Logging

All logs reside on the AIX host:

* freeze.log: output from the freeze.sh script
* waitforsnaps.log: output from the remote python script
* thaw.log: output from the thaw.sh script

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module. You can get a copy and read about it here:

<https://github.com/cohesity/community-automation-samples/tree/main/python>
