# EPIC Pure Freeze Thaw PreScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script can be used as a Pre Script in a Cohesity Pure FlashArray volume backup to freeze an EPIC database, snapshot the related Pure volumes, and thaw the database prior to the volume backup starting.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/bash/epic_pure_freeze_thaw/epic_pure_freeze_thaw.sh
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

## On the Pure FlashArray

Log into the Pure FlashArray and perform the following steps:

* Create a user for the script to use to log into the Pure FlashArray
* Paste the ssh public key for the AIX / Linux user into the field provided
* Create a Pure Protection Group and add all EPIC related volumes to the group

## Back on the Script Host

Edit the script and make the following changes:

* Change first line to `#!/bin/ksh` (AIX) or `#!/bin/bash` (Linux)
* Modify the settings section of the script:

```bash
testing=1      # 1 = skip freeze/thaw (for testing), 0 = perform freeze/thaw (production)
PRIVKEY_PATH="-i /root/.ssh/id_rsa"    # path to ssh private key
PURE_USER="puresnap"                   # user name on Pure FlashArray
PURE_ARRAY="10.1.1.10"                 # FQDN or IP of Pure FlashArray
PURE_SRC_PGROUP="EpicProtectionGroup"  # Name of Pure Protection Group on Pure FlashArray
```

* Uncomment and inspect file system freeze sections of the script where needed

Also, edit the `/etc/ssh/sshd_cohfig` and set:

```bash
MaxStartups 50:30:150  # the first number must be 24 or higher
```

And restart sshd:

```bash
systemctl restart sshd.service  # Linux
stopsrc -g ssh && startsrc -g ssh  # AIX
```

## Create a Cohesity Pure FlashArray Protection Group

Create Cohesity protection group and select all of the EPIC-related volumes. Choose or create a protection policy that has retries set to 0.

Under Additional Settings, under the Pre and Post Scripts option, configure the following:

* The hostname or IP of the script host
* The AIX/Linux username
* Enable `Pre Script`
* The full path to the script, e.g. /home/root/scripts/freezethaw.sh
* Enter a comma-separated list of volume groups (AIX) to freeze (if any), e.g. volgrp1,volgrp2,volgrp3
* Disable `Continue Backup if Script Fails`
* Disable `Post Script`

Also, copy the Cluster SSH Public Key provided and add that to the AIX/Linux user's authorized_keys file on the script host.

## Testing the Script

When the Cohesity Protection Group runs, the Pre Script will run once for each protected EPIC volume. You can monitor the script output log on the script host:

```bash
tail -f /tmp/cohesity_snap.log
```

The first instance of the script (the leader) will perform the EPIC freeze / Pure snapshots / EPIC thaw while the others will wait for the leader to finish. Once the snapshots are created and the database and file systems are thawed, the Pure volume backups will begin. Note that these snapshots will be deleted at a later time, as configured in the Cohesity protection group (see the `Retain on Pure Storage Array` setting under Additional Settings).
