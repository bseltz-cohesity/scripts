# EPIC Pure Freeze Thaw PreScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script can be used as a Pre Script in a Cohesity Pure FlashArray volume backup to freeze an EPIC database, snapshot the related Pure volumes, and thaw the database prior to the volume backup starting.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/epic_pure_freeze_thaw/epic_pure_freeze_thaw.sh
chmod +x epic_pure_freeze_thaw.sh
# End download commands
```

## On the Script Host (AIX or Linux)

* Create or select a user to run the script. The script requires no special access on the host. Create or identify an ssh key pair that we will use when authenticating to the Pure FlashArray. To create an ssh key pair, use the command:

```bash
ssh-keygen
```

* Copy the script onto the host and make the script executable using the command:

```bash
chmod +x epic_pure_freeze_thaw.sh
```

* Edit the script and change first line to `#!/bin/ksh` (AIX) or `#!/bin/bash` (Linux)

* Edit the `/etc/ssh/sshd_cohfig` and set:

```bash
MaxStartups 34:30:124  # default is 10:30:100, add 24 to the first and last numbers
```

* Restart sshd:

```bash
systemctl restart sshd.service  # Linux
stopsrc -s ssh && startsrc -s ssh  # AIX
```

* Copy the AIX / Linux user's SSH public key (will use this in the next steps)

## On the Pure FlashArray

Log into the Pure FlashArray and perform the following steps:

* Create or select a Pure user for the script to use to log into the Pure FlashArray
* Paste the ssh public key for the AIX / Linux user into the field provided
* Create or identify a Pure Protection Group and add all EPIC related volumes to the group

## Create a Cohesity Pure FlashArray (SAN) Protection Group

Log into the Cohesity UI and create a Cohesity (SAN) protection group and select all of the EPIC-related volumes (the same volumes in the Pure protection group).

* Choose or create a protection policy that has `retries set to 0`.

Under Additional Settings, under the Retain on Pure Storage Array option:

* Select `Last Snapshots`
* Set the value to at least 1 (or higher if desired)

Under Additional Settings, under the Pre and Post Scripts option, configure the following:

* The hostname or IP of the script host
* The AIX/Linux username
* Enable `Pre Script`
* The full path to the script, e.g. /home/root/scripts/epic_pure_freeze_thaw.sh
* Enter script parameters (see parameters and examples below)
* Disable `Continue Backup if Script Fails`
* Disable `Post Script`
* Copy the cluster SSH public key provided and add that to the AIX/Linux user's `authorized_keys` file on the script host.

## Parameters

* -t: set to 1 for testing (don't freeze/thaw epic), set to 0 (or omit) to freeze/thaw epic
* -k: private key path for ssh to pure array (e.g. /home/root/.ssh/id_rsa)
* -p: pure array username
* -a: pure array DNS name or IP
* -g: pure protection group name (comma separate multiple, e.g. pg1,pg2,pg3)
* -i: epic instance name
* -e: epic user (e.g. epicadm)
* -v: volume groups to freeze (AIX only) e.g. EpicVolGroup1,EpicVolGroup2,EpicVolGroup3
* -s: create pure protection group snapshots (i.e. SafeMode snapshots)

## Example Parameters

```bash
# linux example parameters
-t 0 -k /home/root/.ssh/id_rsa -p puresnap -a 10.1.1.39 -g EpicProtectionGroup26 -i prod -e epicadm -s

# AIX example parameters
-t 0 -k /home/root/.ssh/id_rsa -p puresnap -a 10.1.1.39 -g EpicProtectionGroup26 -i prod -e epicadm -v EpicVolGroup1,EpicVolGroup2,EpicVolGroup3 -s
```

## Testing the Script

When the Cohesity Protection Group runs, the Pre Script will run once for each protected EPIC volume. You can monitor the script output log on the script host:

```bash
tail -f /tmp/cohesity_snap.log
```

The first instance of the script (the leader) will perform the EPIC freeze / Pure snapshots / EPIC thaw while the others will wait for the leader to finish. Once the snapshots are created and the database and file systems are thawed, the Pure volume backups will begin.

## Recommended Tuning Parameters

You can set the following magneto gflag to optimize the performance of the Pure volume backups:

```yaml
magneto_pure_disk_area_block_size: 1048576
```
