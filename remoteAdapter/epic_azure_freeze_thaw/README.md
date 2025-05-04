# Epic Azure Freeze Thaw Remote Adapter Script

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Introduction

This bash script can be used to freeze Epic Iris DB running in an Azure VM, snapshot the data disks, mount the snapshot disks to a mount host VM, then start a protection group to backup the mount host.

The script provided here is intended to be deployed onto the Epic Iris DB VM, where it can freeze/thaw Iris. The script performs the following operations:

1. Connects to Cohesity to check if the mount host protection group is already running, and if so, aborts the script.
2. Connects to Azure via Azure CLI
3. Deletes any old snapshots
4. Detaches any old data disks from the mount host
5. Freezes Iris
6. Creates new snapshots of the Iris data disks
7. Thaws Iris
8. Creates new data disks from the new snapshots
9. Optionally deletes the new snapshots
10. Attaches the new disks to the mount host
11. Runs the mount host backup (optionally waiting for completion)
12. Optionally detach and delete the disks from the mount host (if we waited for backup completion)

## Azure Portal - Entra ID

As you can see above, we will use Azure CLI to perform snapshot and disk operations. We will need a service identity created (usually in Entra ID) to allow Azure CLI to authenticate to Azure. This identity will require the permissions to create/delete the snapshots of the Iris VM disks, create/delete and attach/detach disks to/from the mount host.

Record the following for the service identity

* Tenant ID
* App ID
* Secret Value

## Azure Portal - Review the Epic Iris VM

Record the following for the Epic VM:

* Subscription ID
* Resource Group Name
* VM Name of Epic Iris VM
* VM Name of Mount Host VM

Review the data disks attached to the Epic Iris VM. Record the following for each disk that you want to include in the backup:

* Disk Name
* Disk Size (in GB)
* Disk SKU (valid options are PremiumV2_LRS, Premium_LRS, Premium_ZRS, StandardSSD_LRS, StandardSSD_ZRS, Standard_LRS, UltraSSD_LRS)

## Prepare the Mount Host

The mount host VM is simply a VM on which we will install the Cohesity agent and mount the snapshot disks, so that we can perform a file based backup of the data through the mount host.

* Install the Cohesity Agent on the mount host and register the mount host as a physical server in the Cohesity cluster
* Create mount paths to mount the data disks, for example:

```bash
/data/snapdisk1
/data/snapdisk2
/data/snapdisk3
```

* Create a pre script to run when the backup starts, that will mount the disks attached by wrapper script. For example:

`/opt/cohesity/agent/software/crux/bin/user_scripts/prescript.sh`

```bash
#!/bin/bash
# example mount commands
sudo mount -o nouuid -t xfs /dev/$(ls -l /dev/disk/azure/scsi1 | grep 'lun4-part1 ' | cut -d' ' -f12 | cut -d'/' -f4) /data/snapdisk1
sudo mount -o nouuid -t xfs /dev/$(ls -l /dev/disk/azure/scsi1 | grep 'lun5-part1 ' | cut -d' ' -f12 | cut -d'/' -f4) /data/snapdisk2
sudo mount -o nouuid -t xfs /dev/$(ls -l /dev/disk/azure/scsi1 | grep 'lun6-part1 ' | cut -d' ' -f12 | cut -d'/' -f4) /data/snapdisk3
# end example mount commands
```

* Also create a post script to unmount at the end of the backup

`/opt/cohesity/agent/software/crux/bin/user_scripts/postscript.sh`

```bash
#!/bin/bash
# example unmount commands
sudo umount /data/snapdisk1
sudo umount /data/snapdisk2
sudo umount /data/snapdisk3
# end example unmount commands
```

## On Cohesity - Create an API Key for Authentication

By default, API Key management is not visible in the Cohesity UI. To make it visible temporarily (for you current web browser session):

1. Log into the Cohesity UI (directly to the cluster, not via Helios) as an admin user
2. In the address bar, enter the url: <https://mycluster/feature-flags>
3. In the field provided, type: api
4. Turn on the toggle for apiKeysEnabled

Then create the API key:

1. Go to Settings -> Access Management -> API Keys
2. Click Add API Key
3. Select the user to associate the new API key
4. Enter an arbitrary name
5. Click Add

`Copy or download the new API key before you leave the page (it will not be visible again)`

## On Cohesity - Create a Physical File-based Protection Group

* Create a physical file-based protection group to protect the mount host. You can select the paths above for inclusion.
* Under additional settings, enable `Pause Future Runs`
* Under Pre/Post scripts, set the prescript to `prescript.sh` and set the postscript to `postscript.sh`

## On Cohesity - Create a Remote Adapter Protection Group

This protection group will require a new Cohesity view, but the view will remain empty as it's just a place holder. Configure the RA job to ssh to the Epic Iris ODB VM using a linux user account, for example `epicadm`.

In the script information fields (for the various job run types) enter the path to the wrapper script on the host, for example: `/home/epicadm/epic_azure_freeze_thaw.sh`

Also copy the ssh key shown in the RA job configuration screen (we will need this later).

## On the Epic Iris ODB Host

* Download the script files

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/remoteAdapter/epic_azure_freeze_thaw/epic_azure_freeze_thaw.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/linux/jobRunning/jobRunning
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/linux/backupNow/backupNow
chmod +x epic_azure_freeze_thaw.sh.sh
chmod +x jobRunning
chmod +x backupNow
# End download commands
```

* Copy the three script files to the location you specified in the RA job (e.g. /home/epicadm), and make sure all of the script files are owned by epicadm and have execute permissions:

```bash
chmod +x backupNow
chmod +x jobRunning
chmod +x epic_azure_freeze_thaw.sh
```

* Install the Azure CLI. See here for instructions: <https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux>
* Append the SSH key copied earier into `/home/epicadm/.ssh/authorized_keys`
* Optionally, if the linux user is not a privileged user, configure the sudoers file to allow the cohesity_script to run some commands as the application user. For example:

```bash
# sudoers entries
cohesity_script ALL=(appuser) NOPASSWD: /bin/sudo -u epidadm /epic/prd/bin/instfreeze, /bin/sudo -u epicadm /epic/prd/bin/instthaw
Defaults:cohesity_script !requiretty
# end sudoers entries
```

* Customize the wrapper script. Edit the top sections of the epic_azure_freeze_thaw.sh wrapper script to ensure all items are configured for your environment.

Notes:

* Use the API key copied above for the CLUSTER_API_KEY
* Use the mount host protection group name for PROTECTION_GROUP_NAME
* Use the Sub scription ID and Resource Group recorded from Azure
* Use the Tenant ID, App ID, and Secret for the Service Principal
* Use the DISK_NAMES recorded from the Azure Epic Iris VM
* Use the DISK_SIZES recorded from the Azure Epic Iris VM
* Use the DISK_SKUS recorded from the Azure Epic Iris VM

```bash
#!/bin/bash

SCRIPT_VERSION="2025-05-04"
LOG_FILE="/home/epicadm/freeze-thaw.log"
SCRIPT_ROOT="/home/epicadm"

# cohesity cluster settings ===============================
CLUSTER_API_KEY="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
PROTECTION_GROUP_NAME="My Protection Group"
CLUSTER_ENDPOINT="mycluster.mydomain.net"
CLUSTER_USER="myuser"

# Azure settings ==========================================
SUBSCRIPTION_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
TENANT_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
APP_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
SECRET="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
RESOURCE_GROUP="Epic_group"

# Disks
SNAP_NAMES=("snap1" "snap2" "snap3")
DISK_NAMES=("disk1" "disk2" "disk3")
NEW_DISK_NAMES=("snapdisk1" "snapdisk2" "snapdisk3")
DISK_SIZES=("1024" "512" "512")
DISK_SKUS=("PremiumV2_LRS" "PremiumV2_LRS" "PremiumV2_LRS")

# Epic settings ===========================================
IRIS_VM_NAME='EpicVM'
MOUNT_HOST_VM_NAME='MountHostVM'
FREEZE_CMD="/bin/sudo -u epicadm /epic/prd/bin/instfreeze"
THAW_CMD="/bin/sudo -u epicadm /epic/prd/bin/instthaw"
```

## Test the Results

Run the script and confirm that everything works as expected. You should see the Iris freeze and thaw, and the Azure commands complete successfully. You should also see the disks mounted on the mount host VM and the Physical File-based Protection Group running to backup the mounted disks.

Once you are happy the script is working fine, you can run the script by running the remote adapter protection group, then let that group run at the desired time.
