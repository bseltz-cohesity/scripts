# EPIC Pure Protection Group Freeze Thaw Scripts

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These bash scripta can be used the pre-script and post-snapshot-script in a Cohesity Pure FlashArray protection group backup to freeze/thaw the EPIC operational database.

## Download the scripts

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/epic_pure_ppg_freeze_thaw/epic_pure_ppg_freeze.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/epic_pure_ppg_freeze_thaw/epic_pure_ppg_thaw.sh
chmod +x epic_pure_ppg_freeze.sh
chmod +x epic_pure_ppg_thaw.sh
# End download commands
```

## On the Script Host (AIX or Linux)

* Create or select a user to run the script. The script requires no special access on the host.
* Copy the scripts onto the host and make the scripts executable using the command:

```bash
chmod +x epic_pure_ppg_freeze.sh
chmod +x epic_pure_ppg_thaw.sh
```

* Edit the script and change first line to `#!/bin/ksh` (AIX) or `#!/bin/bash` (Linux)

## On Cohesity Create a Cohesity Pure FlashArray (SAN) Protection Group

Log into the Cohesity UI and create a Cohesity (SAN) protection group and select the EPIC-related Pure Protection Groups (PPGs).

* Choose or create a protection policy that has `retries set to 0`.

Under Additional Settings, under the Retain on Pure Storage Array option:

* Select `Last Snapshots`
* Set the value to at least 1 (or higher if desired)

Under Additional Settings, under the Pre and Post Scripts option, configure the following:

* The hostname or IP of the script host
* The AIX/Linux username
* Enable `Pre Script`
* Enter the full path to the freeze script, e.g. /home/root/scripts/epic_pure_ppg_freeze.sh
* Enter the script parameters (see parameters and examples below)
* Disable `Continue Backup if Script Fails`
* Disable `Post Backup Script`
* Enable `Post Snapshot Script`
* Enter the full path to the thaw script, e.g. /home/root/scripts/epic_pure_ppg_thaw.sh
* Enter the script parameters (see parameters and examples below)
* Copy the cluster SSH public key provided and add that to the AIX/Linux user's `authorized_keys` file on the script host (usually in /home/username/.ssh).

## Parameters

* -t: set to 1 for testing (don't freeze/thaw epic), set to 0 (or omit) to freeze/thaw epic
* -i: epic instance name
* -e: epic user (e.g. epicadm)
* -v: volume groups to freeze (AIX only) e.g. EpicVolGroup1,EpicVolGroup2,EpicVolGroup3

## Example Parameters

```bash
# linux example parameters
-t 0 -i prod -e epicadm

# AIX example parameters
-t 0 -i prod -e epicadm -v aixvol1,aixvol2,aixvol3
```

## Testing the Script

When the Cohesity Protection Group runs, the Pre Script will run once for each protected PPG. You can monitor the script output log on the script host:

```bash
tail -f /tmp/cohesity_snap.log
```

The first instance of the script (the leader) will perform the EPIC freeze / EPIC thaw while the others will wait for the leader to finish.

## Recommended Tuning Parameters

You should set the following magneto gflag to optimize the performance and storage efficiency of the Pure volume backups:

```yaml
magneto_pure_disk_area_block_size: 1048576
```
