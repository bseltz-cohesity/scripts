# Start and Stop Cohesity Cloud Edition

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script stops and starts Cohesity Cloud Edition on a schedule. When stopping the cluster, it waits for a job to finish.

## Components

* cohesity_cluster.sh: the main bash script
* waitForJob.py: python script to wait for job completion
* pyhesity.py: the Cohesity REST API helper module

## Instructions

The script is designed to run on the AWS Control VM. First create a scripts folder, then download the scripts into the folder:

```bash
# begin commands
mkdir /home/cohesity/scripts
cd /home/cohesity/scripts
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/cloud/cohesity_cluster.sh
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/cloud/pyhesity.py
curl -O https://github.com/bseltz-cohesity/scripts/blob/master/cloud/waitForJob.py
chmod +x cohesity_cluster.sh
# end commands
```

Next, modify the contents of the cohesity_cluster.sh to set the correct cluster, username, domain name, and path to the cluster_config json file.

Finally, we will create CRON entries to lanch the cohesity_cluster.sh script at the times of day when we want the cluster to start and stop. Note that when the stop command is issued, it will wait for the currently running job to complete.

## A note about timezones

The cohesity AWS Control VM is set to UTC time by default. So either adjust the timezone on that VM or adjust your start/stop times accordingly.

## CRON entries

Example: start the cluster at 5PM, and stop it at 5AM

```bash
0 17 * * * /home/cohesity/scripts/cohesity_cluster.sh start
0 5 * * * /home/cohesity/scripts/cohesity_cluster.sh stop
```
