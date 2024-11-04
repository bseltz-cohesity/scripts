# Qumulo Snapshot-based Backup Toolkit

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These scripts enable snapshot-based backups of Qumulo SMB shares and NFS exports.

## Download the scripts

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/qumuloSnapper/prescript-example.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/qumuloSnapper/qumuloSnap.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/backupNow/backupNow.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x prescript-example.sh
chmod +x qumuloSnap.py
chmod +x backupNow.py
# end download commands
```

## Components

* prescript-example.sh wrapper script
* qumuloSnap.py: python script to manage Qumulo snapshots
* backupNow.py: ptthon script to start Cohesity backups
* pyhesity.py: the Cohesity REST API helper module

## Basic Workflow

The scripts will connect to Cohesity and inspect a NAS protection group. For each Qumulo SMB share or NFS export, it will delete any existing snapshots (with a particular name suffix), and create a new snapshot. The protected shares/exports will be updated to point to the new snapshot directories, and then the protection group will be started. The protection group will therefore always backup quiesced snapshots rather than the live file system, where open/locked files could interfere with the backup.

## Setup Instructions

Register your Qumulo SMB shares and NFS exports as protection sources (of type NAS -> Mount Point) on your Cohesity cluster, and create a NAS protection group that protects them. Choose a policy for this protection group that specifies the desired retention of the backups, plus any replication or archiving requirements. Note that the frequency of the backup will be controlled separately (read on). Leave this protection group in a paused state ("pause future runs"), as the group will be run via API rather than by schedule. Note that if you have multiple Qumulo clusters, any protection group should only protect shares/exports from a `single` Qumulo cluster.

## Choose a Linux Host to Run the Scripts

Next, identify a linux host where we can run bash and python scripts. This host must be able to reach both the Qumulo and Cohesity clusters over the network to send API commands. You can create a user on the linux host if desired, for example:

```bash
useradd cohesity-script
passwd cohesity-script
```

Then you can copy the script files to the user's home directory.

## Python and Dependencies

Python is usually included with most linux installations, and the version of Python won't matter as long as it's relatively modern (e.g. 2.7 or later). One Python module called `requests` will need to be installed (as it is not included in the Python standard library). The module can be installed in a few ways; via yum:

```bash
yum install python-requests
```

or via pip:

```bash
pip install requests
```

Note that for Python 3.x, these commands may differ. The yum package may be called `python3-requests`, and the pip command may be `pip3`.

## Modify the PreScript

Edit the prescript-example.sh and modify the settings at the top of the file to match your environment:

```bash
COHESITY_CLUSTER=mycluster.mydomain.net  # The DNS name of IP of the Cohesity cluster to connect to
COHESITY_USER=mydomain.net\\nasuser      # The domain\username to connect to the Cohesity cluster
COHESITY_PROTECTION_GROUP=QumuloBackup   # The name of the NAS protection group to operate on
QUMULO=qumulo1.mydomain.net              # The DNS name or IP of the Qumulo cluster to connect to 
QUMULO_USER=quser                        # The username to connect to the Qumulo cluster
SMB_USER=mydomain.net\\nasuser           # The SMB user used in the Qumulo SMB protection sources
```

Notice that there are no passwords in the file, we will handle those next.

## Test the Scripts

Make sure the prescript-example.sh is marked executable:

```bash
chmod +x prescript-example.sh
```

then run the script:

```bash
./prescript-example.sh
```

You will be prompted for the passwords required for access to the Cohesity cluster, the Qumulo cluster and the SMB access user. These passwords will be stored in secure password storage so that the script can run unattended later.

When the script runs, it will connect to Qumulo and take snapshots of the shares/exports in the specified protection group, and update the protection sources to point to the new snapshot directories. Then it will initiate the NAS protection group.

If successful we will next configure a Remote Adapter protection group to run the script on a schedule.

## Create a Remote Adapter Protection Group

This Remote Adapter protection group is the orchestrator of the workflow. It will periodically run the script and trigger the run of the NAS protection group.

First create a new Cohesity View. The view settings are not important, this is just an empty view for use with the Remote Adapter protection group.

Then create a Remote Adapter protection group. Choose a policy that matches your desired backup frequency (this will determine the frequecy of the NAS backup, while the retention, replication and archiving will be determined by the policy assigned to the NAS protection group). Configure the RA group to connect to our linux host and user, and provide the full path to the prescript-example.sh, like `/home/cohesity-script/prescript-example.sh`

Copy the ssh key provided and add it to our linux user's authorized_keys file, e.g. `/home/cohesity-script/.ssh/authorized_keys`

Finally, choose "Run Now" on the new Remote Adapter protection group. While it's running, click to inspect the current run, and click on the view name to see the detailed logs. You should see output from our scripts in the logs, showing that snapshots are being created and the NAS protection group is started. You can then look at the running NAS protection group and verify that it is backing up the shares/exports using the new snapshot directories.

## Behaviors and Caveats

When the Remote Adapter protection group runs the script, it connects to Cohesity and inspects the NAS protection group. If the group is already running, the script aborts, so as not to interfere with the current backup.

If the group is not already running, then it gets the list of NAS shares/exports protected by the NAS protection group. For each share/export, it finds and deletes any existing snapshots, with the naming convention of id_suffix. By default, the suffix is `cohesity`. This can be adjusted using the `-s, --snapsuffix` parameter of the qumuloSnap.py script (see parameters section below). It then will create a new snapshot with the same naming convention.

The script will then update the Cohesity protection source for that share/export, updating the mount path to point to the snapshot directory, e.g. `\\qumulo1\share1\.snapshot\123_cohesity`. When the NAS protection group runs, it will backup this directory.

As mentioned above, the NAS protection group must only protect shares/exports from one Qumulo cluster. If there is more than one Qumulo cluster to protect, we must protect those shares/exports in a different NAS protection group.

## Managing Multiple NAS Protection Groups

One Remote Adapter protection group can manage multiple NAS protection groups. We simply have to duplicate/repeat the entire contents of the prescript-example.sh once for each NAS protection group, such that there is a script stanza per NAS protection group with the proper settings.

## Authentication Parameters for qumuloSnap.py

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to

## Other Parameters for qumuloSnap.py

* -j', '--jobname: name of the NAS protection group to operate on
* -q, --qumulo: DNS name or IP of the Qumulo cluster to connect to
* -qu, --qumulo_user: username to connect to the Qumulo cluster
* -qp, --qumulo_passwd: (optional) password of the Qumulo user
* -s, --snapsuffix: (optional) defaults to 'cohesity'
* -su, --smbusername: SMB user used in the Qumulo SMB protection sources
* -sp, --smbpasswd: (optional) SMB password used in the Qumulo SMB protection sources

## Parameters for backupNow.py

Please see here for backupNow.py parameters: <https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow#parameters>
