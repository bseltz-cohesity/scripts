# Linux VM Freeze Thaw Script

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script can be used as a VMTools Freeze/Thaw Script for a Cohesity VMware backup to freeze and thaw applications running in a Linux VM.

## Download the script

```bash
# Begin download commands
sudo mkdir /etc/vmware-tools/backupScripts.d
cd /etc/vmware-tools/backupScripts.d
sudo curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/linux_vm_freeze_thaw/linux_vm_freeze_thaw.sh
sudo chmod +x linux_vm_freeze_thaw.sh
# End download commands
```

## On the Script Host (Linux)

* Create a directory /etc/vmware-tools/backupScripts.d

```bash
sudo mkdir /etc/vmware-tools/backupScripts.d
```

* Copy the script into that directory and make it executable

```bash
sudo chmod +x /etc/vmware-tools/backupScripts.d/linux_vm_freeze_thaw.sh
```

* Edit the script and modify the settings to define your freeze and thaw commands.

## Create a Cohesity VMware Protection Group

* Edit the VMware protection group. Under Additional Settings, enable `App Consistent Backups` and disable `Take a Crash Consistent backup if unable to perform an App Consistent backup`
* Choose or create a protection policy that has `number of retries set to 0`.

## Testing the Script

When the Cohesity Protection Group runs, the script should fire a freeze command, followed by a thaw command. These actions will be logged in /tmp/cohesity_snap.log

```bash
tail -f /tmp/cohesity_snap.log
```
