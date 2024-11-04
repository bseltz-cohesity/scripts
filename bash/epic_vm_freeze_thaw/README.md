# EPIC VM Freeze Thaw Script

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script can be used as a VMTools Freeze/Thaw Script for a Cohesity VMware backup to freeze and thaw an EPIC database.

## Download the script

```bash
# Begin download commands
sudo mkdir /etc/vmware-tools/backupScripts.d
cd /etc/vmware-tools/backupScripts.d
sudo curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/epic_vm_freeze_thaw/epic_vm_freeze_thaw.sh
sudo chmod +x epic_vm_freeze_thaw.sh
# End download commands
```

## On the Script Host (Linux)

* Create a directory /etc/vmware-tools/backupScripts.d

```bash
sudo mkdir /etc/vmware-tools/backupScripts.d
```

* Copy the script into that directory and make it executable

```bash
sudo chmod +x /etc/vmware-tools/backupScripts.d/epic_vm_freeze_thaw.sh
```

* Edit the script and modify the basic settings to match your Epic environment

## Optional Pure Storage Array Safe Mode Snapshots

* Copy the root user's SSH public key (will use this in the next steps)
* Log into the Pure FlashArray and perform the following steps:
* Create or select a Pure user for the script to use to log into the Pure FlashArray
* Paste the ssh public key for the AIX / Linux user into the field provided
* Create or identify a Pure Protection Group (PPG) and add all EPIC related VM datastores to the PPG
* Configure safe mode policy for the PPG (define the retention, but no schedule)
* Edit the script to set SNAPPG=1 and configure the remaining safe mode settings

## Create a Cohesity VMware Protection Group

* Edit the VMware protection group. Under Additional Settings, enable `App Consistent Backups` and disable `Take a Crash Consistent backup if unable to perform an App Consistent backup`
* Choose or create a protection policy that has `number of retries set to 0`.

## Testing the Script

When the Cohesity Protection Group runs, the script should fire a freeze command, followed by a thaw command. These actions will be logged in /tmp/cohesity_snap.log

```bash
tail -f /tmp/cohesity_snap.log
```
