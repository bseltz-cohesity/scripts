# Backup Helios Self-Managed Virtual Edition

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script shuts down Helios VMs, performs a backup and starts the VMs again.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/heliosVEbackup/heliosVEbackup.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/vmware/python/powerOnVMs/powerOnVMs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/vmware/python/shutdownVMs/shutdownVMs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/vmware/python/vmMacAddresses/vmMacAddresses.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/heliosMonitor/heliosMonitor.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x heliosVEbackup.sh
# End download commands
```

## Configuring the Scripts

Place all of the script files in a folder together. Then edit the top sections of `heliosVEbackup.sh` to match your environment:

```bash
cd ~/scripts/python

# settings =====================================
vCenter='myvcenter.mydomain.net'
vCenterUser='administrator@vsphere.local'
vms='my-helios-vm1,my-helios-vm2,my-helios-vm3,my-helios-vm4'

heliosEndPoint='myhelios.mydomain.net'
heliosUser='admin'

cluster='mycluster.mydomain.net'
clusterUser='myuser'
pg='myVMprotectionGroup'

logfile='log-heliosVEBackup.txt'
# end settings =================================
```

## Test the Script

`Warning:` when you run the script, Helios will shut down. Please consider testing off hours.

When ready to test the script, cd into the folder where the scripts are located, then type

```bash
./heliosVEbackup.sh
```

The script will do the following:

* Starts a log file (e.g. log-heliosVEbackup.txt)
* Records the MAC addresses of the VMs to the log file
* Shutdown the Helios VMs
* Wait for shutdowns to complete
* Connect to the Cohesity cluster (the first time you run the script, you will be prompted for the password of your Cohesity user, this will be stored for later unattended use)
* Run the protection group that backs up the VMs
* Wait for protection run to finish
* Starts the VMs
* Waits for Helios to be responsive again

## Run the Script on a Schedule

We can schedule the script to run using cron.

```bash
crontab -e
```

Let's say that you want the script to run every morning at 4am.

```bash
# crontab example
0 4 * * * /scripts/heliosVEbackup.sh
# end crontab example
```
