# EPIC Pure Freeze Thaw Standalone Script

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script freezes an EPIC database, snapshots the related Pure volumes, and thaws the database. This script is not for use with Cohesity backups but is just a tool to make a clean snapshot of Epic.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/epic_pure_snapper/epic_pure_snapper.sh
chmod +x epic_pure_snapper.sh
# End download commands
```

## On the Script Host (AIX or Linux)

* Create or select a user to run the script. The script requires no special access on the host. Create or identify an ssh key pair that we will use when authenticating to the Pure FlashArray. To create an ssh key pair, use the command:

```bash
ssh-keygen
```

* Copy the script onto the host and make the script executable using the command:

```bash
chmod +x epic_pure_snapper.sh
```

* Edit the script and change first line to `#!/bin/ksh` (AIX) or `#!/bin/bash` (Linux)

* Copy the AIX / Linux user's SSH public key (will use this in the next steps)

## On the Pure FlashArray

Log into the Pure FlashArray and perform the following steps:

* Create or select a Pure user for the script to use to log into the Pure FlashArray
* Paste the ssh public key for the AIX / Linux user into the field provided
* Create or identify a Pure Protection Group and add all EPIC related volumes to the group

## Parameters

* -t: set to 1 for testing (don't freeze/thaw epic), set to 0 (or omit) to freeze/thaw epic
* -k: private key path for ssh to pure array (e.g. /home/root/.ssh/id_rsa)
* -p: pure array username
* -a: pure array DNS name or IP
* -g: pure protection group name (comma separate multiple, e.g. pg1,pg2,pg3)
* -i: epic instance name
* -e: epic user (e.g. epicadm)
* -v: volume groups to freeze (AIX only) e.g. EpicVolGroup1,EpicVolGroup2,EpicVolGroup3

## Example Parameters

```bash
# linux example
./epic_pure_snapper.sh -t 0 -k /home/root/.ssh/id_rsa -p puresnap -a 10.1.1.39 -g EpicProtectionGroup26 -i prod -e epicadm

# AIX example
./epic_pure_snapper.sh -t 0 -k /home/root/.ssh/id_rsa -p puresnap -a 10.1.1.39 -g EpicProtectionGroup26 -i prod -e epicadm -v EpicVolGroup1,EpicVolGroup2,EpicVolGroup3
```

## Testing the Script

When the script is run, you can monitor the script output log on the script host:

```bash
tail -f /tmp/cohesity_snap.log
```
