# EPIC Freeze Thaw Remote Adapter Script

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script can be used as a pre-script in a remote adapter job to freeze an EPIC database, run a Pure volume backup job and thaw the EPIC database. The script will call the included python scripts during the process to monitor and run the Pure job.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/bash/epic_freeze_thaw/epic_freeze_thaw.sh.sh
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/jobRunning/jobRunning.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/backupNow/backupNow.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x epic_freeze_thaw.sh.sh
chmod +x jobRunning.py
chmod +x backupNow.py
# End download commands
```

## Components

* epic_freeze_thaw.sh.sh: the wrapper script
* jobRunning.py: python script to check if Pure job is already running
* backupNow.py: python script to start and monitor the Pure job
* pyhesity.py: Cohesity python function library

## Create a Pure Protection Group

First, create a Pure protection group, protecting the Pure volumes that hold the Epic database, and leave it paused.

## Create a Remote Adapter Protection Group

This protection group will require an new Cohesity view to backup, but the view will remain empty as it's just a place holder. Configure the RA job to ssh to the EPIC host using a user account, for example `cohesity_script`.

In the script information fields (for the various job run types) enter the path to the wrapper script on the host, for example: `/home/cohesity_script/epic_freeze_thaw.sh`

Also copy the ssh key shown in the RA job configuration screen

## Dependencies for the Epic Host

We will require python 2.7 or later to be installed, plus the python `requests` module: <https://pypi.org/project/requests/>

## On the Epic Host

On the host, create the user cohesity_script and copy the four script files to the location you specified in the RA job.

Configure the sudoers file to allow the cohesity_script to run some commands as the epicadm user:

```bash
# sudoers entries
cohesity_script ALL=(epicadm) NOPASSWD: /bin/sudo -u epicadm /epic/prod/bin/instfreeze, /bin/sudo -u epicadm /epic/prod/bin/instthaw
Defaults:cohesity_script !requiretty
# end sudoers entries
```

Also append the SSH key copied earier into `/home/cohesity_script/.ssh/authorized_keys`

make sure all of the script files are owned by cohesity_script and have execute permissions:

```bash
-rwxr-xr-x. 1 cohesity_script cohesity_script 26604 Oct 19 09:27 backupNow.py
-rwxr-xr-x. 1 cohesity_script cohesity_script  1760 Oct 19 09:28 jobRunning.py
-rwxr-xr-x. 1 cohesity_script cohesity_script 30146 Oct 19 09:31 pyhesity.py
-rwxr-xr-x. 1 cohesity_script cohesity_script  1230 Oct 19 14:59 epic_freeze_thaw.sh
```

## Customize the Wrapper Script

Edit the top few lines of the epic_freeze_thaw.sh wrapper script to ensure all items are configured for your environment:

```bash
#!/bin/bash

CLUSTER_API_KEY="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"
PROTECTION_GROUP_NAME="pure backup"
CLUSTER_ENDPOINT="mycluster"
CLUSTER_USER="cohesity_script"

FREEZE_CMD="/bin/sudo -u epicadm /epic/prod/bin/instfreeze"
THAW_CMD="/bin/sudo -u epicadm /epic/prod/bin/instthaw"
```

## Generate an API Key

To generate an API key, log onto the Cohesity UI, and go to Settings -> Access Management -> API Keys. Click `Add API Key`.

Select the cohesity_script user, enter an arbitrary key name and click `Add`. Copy the API Key token on the next screen and use it in the wrapper script as shown above.

## Test the Results

Finally, run the RA job. The job should run the script which will check to ensure the Pure job is not running, then freeze Epic, start the Pure job, monitor for the Pure snapshots to be taken, thaw Epic, then complete the backup of the Pure volumes.
