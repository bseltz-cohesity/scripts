# VM Freeze Thaw Remote Adapter Script

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script can be used as a pre-script in a remote adapter job to freeze an application, run a VM backup job and thaw the application. The script will call the included commands during the process to monitor and run the VM job.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/remoteAdapter/vm_freeze_thaw/vm_freeze_thaw.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/jobRunning/jobRunning.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/backupNow/backupNow.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py
chmod +x vm_freeze_thaw.sh
chmod +x jobRunning.py
chmod +x backupNow.py
# End download commands
```

## Components

* vm_freeze_thaw.sh.sh: the wrapper script
* jobRunning: linux command to check if VM job is already running
* backupNow: linux command to start and monitor the VM job

## Create a VM Protection Group

First, create a VM protection group, protecting the VMs that hold the application, and leave it paused.

## Create a Remote Adapter Protection Group

This protection group will require an new Cohesity view to backup, but the view will remain empty as it's just a place holder. Configure the RA job to ssh to the application host using a linux user account, for example `cohesity_script`.

In the script information fields (for the various job run types) enter the path to the wrapper script on the host, for example: `/home/cohesity_script/vm_freeze_thaw.sh`

Also copy the ssh key shown in the RA job configuration screen

## On the Application Host

On the host, create the user cohesity_script and copy the four script files to the location you specified in the RA job.

Configure the sudoers file to allow the cohesity_script to run some commands as the application user:

```bash
# sudoers entries
cohesity_script ALL=(appuser) NOPASSWD: /bin/sudo -u appuser /appuser/freeze_command, /bin/sudo -u appuser /appuser/thaw_command
Defaults:cohesity_script !requiretty
# end sudoers entries
```

Also append the SSH key copied earier into `/home/cohesity_script/.ssh/authorized_keys`

make sure all of the script files are owned by cohesity_script and have execute permissions:

```bash
-rwxr-xr-x. 1 cohesity_script cohesity_script 26604 Oct 19 09:27 backupNow
-rwxr-xr-x. 1 cohesity_script cohesity_script  1760 Oct 19 09:28 jobRunning
-rwxr-xr-x. 1 cohesity_script cohesity_script  1230 Oct 19 14:59 vm_freeze_thaw.sh
```

## Customize the Wrapper Script

Edit the top few lines of the vm_freeze_thaw.sh wrapper script to ensure all items are configured for your environment:

```bash
#!/bin/bash

CLUSTER_API_KEY="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"
PROTECTION_GROUP_NAME="VM backup"
CLUSTER_ENDPOINT="mycluster"
CLUSTER_USER="cohesity_script"

FREEZE_CMD="/bin/sudo -u appuser /appuser/freeze_command"
THAW_CMD="/bin/sudo -u appuser /appuser/thaw_command"
```

## Generate an API Key

To generate an API key, log onto the Cohesity UI, and go to Settings -> Access Management -> API Keys. Click `Add API Key`.

Select the cohesity_script user, enter an arbitrary key name and click `Add`. Copy the API Key token on the next screen and use it in the wrapper script as shown above.

## Test the Results

Finally, run the RA job. The job should run the script which will check to ensure the VM job is not running, then freeze the application, start the VM job, monitor for the VM snapshots to be taken, thaw the application, then complete the backup of the VMs.
