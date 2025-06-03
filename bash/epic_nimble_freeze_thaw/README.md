# EPIC Nimble Freeze Thaw PreScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script can be used as a Pre Script in a Cohesity Physical file-based backup to freeze an EPIC database, snapshot the related Nimble volumes, and thaw the database prior to the backup starting.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/epic_nimble_freeze_thaw/epic_nimble_freeze_thaw.sh
chmod +x epic_nimble_freeze_thaw.sh
# End download commands
```

## On the Mount Host (AIX or Linux)

* The script will be executed by the Cohesity agent, and so will run under that user context. The script will need password-less SSH to the Iris host as well as the Nimble array. So we will need an SSH key pair that can be granted that access. To create an SSH key pair, SSH into the mount host as the Cohesity agent user and run:

```bash
ssh-keygen
```

* SSH to the Nimble Array and add the SSH key, for example:

```bash
sshkey --add epickey --type rsa --key ZZZZB4NzZC1yc2EZZZZDZQZBZZZBgfakekeybDZOhocfNLz4fakekeyWJ/ozfakekeyYbQLT+/b7xTEPcr6/fU0FPufakekeyn+2fI9Q7LtTqdwyfakekey/EFG4BzmKnYfakekey/V+97LTOcNsfakekeyro/smvcfakekeyUdU7emTUIPUFfIfakekeyndQ6zo1t2VldrPewKKxsDrzvnbhXeBu4vf4fTPExfakekeyZzbNZZMhUmffkNxMDY/ZWF4Mfakekey6z7Zl6fW8YcPoNv6/w6W9nm+jn9g/+SZPWQoBxn7yVtYss6iFYyFvbglM/Qs7vUlYJuwKXppKvCCINQpNM4iQwFdfGrS0XTrfMElGdHrZ446WL2t64YJHn9sENtjZvzPu0pzqE4v7YIZRIe2nZb48ZJ481OJ+4RtoSeoD4yBnVC2r44p6ZcOZYn8rPXcj+y6Hk82HMyZoZyKx94p0X/b6XW71Q8bfF6SiD+MwiotuISyhffyulNKoIIHtZV4Cl6iXo9wnkkwyOQVkXWrxGE=
```

* Copy the key to the Iris host as well:

```bash
ssh-copy-id epicadm@irishost
```

* Copy the script onto the host to the user script path (typically `/opt/cohesity/agent/software/crux/bin/user_scripts/`) and make the script executable using the command:

```bash
chmod +x epic_nimble_freeze_thaw.sh
```

* Edit the script and change first line to `#!/bin/ksh` (AIX) or `#!/bin/bash` (Linux)

* Also edit the settings sections of the script to match your environment

```bash
# Iris host settings
IRIS_USER="epicadm"
IRIS_HOST="192.168.1.251"
FREEZE_CMD="/epic/prd/bin/instfreeze"
THAW_CMD="/epic/prd/bin/instthaw"

# storage array settings
NIMBLE_USER="admin"
NIMBLE_ARRAY="192.168.1.17"
VOL_NAMES=("EPICODB-1" "EPICODB-2" "EPICODB-3")

# mount host settings
MOUNT_PATH="/epic/prd"
VOLUME_GROUP="epicodb"
LOGICAL_VOLUME="lvol0"
```

## Testing the Script

You can run the script manually from the command line of the mount host to monitor success/failure.

## Create the Protection Group

Create a file-based protection group to protect the mount host, including the paths that will be mounted when the script runs.

Configure the protection group to use the script as a prescript.
