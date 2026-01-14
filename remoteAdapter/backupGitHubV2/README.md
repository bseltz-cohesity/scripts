# Backup GitHub Repositories Using Remote Adapter Script

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script can be used as a pre-script in a remote adapter job to backup GitHub repositories.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/remoteAdapter/backupGitHubV2/backupGitHub.sh
chmod +x backupGitHub.sh
# End download commands
```

## Create a Cohesity View

Create a Cohesity View to store the backups for your GitHub repositories. Recommend that you use the "File Share" template, which enables NFS access (required) and uses the TestAndDevHigh performance profile (recommended).

## Choose a Linux Host to Run the Script

Select a Linux host where we can run the bash script. The script will mount the view, query the specifiec GitHub organization for all repositories, and clone new or pull (sync) existing repositories into the View. On the Linux host, create or select the desired user account and place the bash file in the user's home directory.

Note that the selected user will require password-less sudo access in order to mount/unmount the View when the script runs.

## Review and Modify the Bash Script

The script contains some example commands to do some initial setup: create the mount directory and install the git and jq packages (this section is commented out after these commands have been run once).

Next, the view is mounted and we cd into the mounted View.

Then, we query GitHub organization for all repositories and loop through all those repositories.  If the repository does not exist locally, the repository will be fully cloned using a `git clone`; otherwise, we'll cd into the target repository and perform an `git pull` to get the latest updates for that repository.

Finally, we unmount the view.

Modify all commands to suite your environment and perform the initial setup steps so that the script successfully mounts the view, performs `git pull` and unmounts the view.

The top of the script has configuration parameters to set specific for your environment.

```bash
# Configuration variables to set specific to your environment
COHESITY_MOUNT_PATH="cohesity-cluster:/view-name"
LOCAL_MOUNT_POINT="/mnt/GitHub-Repos"
GITHUB_ORG="organization_name"         # This is a GitHub organization name that the repositories reside in
GITHUB_PAT="ghp_private_access_token"  # This is a legacy personal access token that must begin with ghp_
```

## Create a Remote Adapter Protection Group

After the script is working, we can create a Remote Adapter protection group to run our script on a schedule.

When creating the protection group:

* Select our Linux host and username
* Copy the cluster ssh public key provided and add this to the ~/.ssh/authorized_keys file of our Linux user
* Select the desired Policy, which will define the frequency and retention of the backups.
* Select our Cohesity View
* In the script information fields, enter the full path to the script, for example: `/home/cohesity_script/backupGitHub.sh`

## Protecting Multiple Repositories

The example script shows how to protect two repositories. For each additional repository, use the git clone command to create/sync the new directory, and then add `cd` and `git pull` commands for that repository.
