# Remote Adapter Example

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script is a basic example of a remote adapter script. It mounts a Cohesity view, runs some command(s) to copy data to the view, then unmounts the view.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/remoteAdapter/remoteAdapterExample/remoteAdapterExample.sh
chmod +x remoteAdapterExample.sh
# End download commands
```

## Create a Cohesity View

Create a Cohesity View to store the backups. Recommend that you use the "File Share" template, which enables NFS access (required) and uses the TestAndDevHigh performance profile (recommended).

## Choose a Host to Run the Script

Select a host where we can run the bash script. The script will mount the view and run your commands to copy data into the View. On the host, create or select the desired user account and place the bash file in the user's home directory.

Note that the selected user will require password-less sudo access in order to mount/unmount the View when the script runs.

## Review and Modify the Bash Script

Update the script to perform your specific backup commands. The example given is a simple file copy command:

```bash
# Perform backup commands
cp /home/myuser/*.sh $MOUNT_PATH
```

Replace this with your command(s)

## Test the Script

You can run the script manually on the host to validate that the script works as expected.

## Create a Remote Adapter Protection Group

After the script is working, we can create a Remote Adapter protection group to run our script on a schedule.

When creating the protection group:

* Specify our host and username
* Copy the cluster ssh public key provided and add this to the ~/.ssh/authorized_keys file of our host user
* Select the desired Policy, which will define the frequency and retention of the backups.
* Select our Cohesity View
* In the script information fields, enter the full path to the script, for example: `/home/cohesity_script/remoteAdapterExample.sh`
