# GPFS Pre and Post Scripts

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These bash scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of GPFS nodes to mount the latest snapshot for any protected file set to a consistent mount path. The assumption is that new snapshots are being created on a schedule by another process.

Note: these scripts have been tested on Linux. No testing has been done yet on AIX.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/gpfs_snap_mounter/prescript.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/gpfs_snap_mounter/postscript.sh
chmod +x prescript.sh
chmod +x postscript.sh
# End download commands
```

## Review the scripts

For AIX you may need to change the first line of the script from `#!/bin/bash` to `#!/bin/ksh`

The `PATH` statement may be unnecessary or may need to be modified to point to the location of the GPFS command line binaries

## On the GPFS Nodes

Install the Cohesity Agent. For example, on Linux you can install the Cohesity agent RPM:

```bash
yum localinstall el-cohesity-agent-6.6.0d_u2-1.x86_64.rpm
```

`Note`: If a local firewall is running on the GPFS node, ensure that port 50051/tcp is open for inbound connections from the Cohesity cluster.

Copy the pre and post scripts into `user_scripts` directory under the installation directory of the Cohesity agent, typically `/opt/cohesity/agent/software/crux/bin/user_scripts/` and make the scripts executable:

```bash
chmod +x prescript.sh
chmod +x postscript.sh
```

## On the Cohesity Cluster

Register the GPFS nodes as physical protection sources. Note the name of the registered sources, which will typically be an FQDN like `gpfsnode1.mydomain.net` (preferred) or an IP address.

Create a physical file-based protection group (one for each GPFS node that you want to protect)

For each protection group, select one GPFS node to protect, and include any file-set paths that you want to include in the backup through that GPFS node. Note that the script will mount the latest snapshot to a consistent file path in the following format:

```bash
/mnt/Cohesity-fileSystemName-fileSetName/
```

You can include multiple file set paths, and you can target subdirectories of a file set, lik so:

```bash
/mnt/Cohesity-fileSystemName-fileSetName//dir1/
```

Under the Additional Settings section of the protection group configuration, enable pre and post scripts, with the following settings:

* Pre Script: Enabled
* Pre Script Path: prescript.sh
* Continue Backup if Script Fails: Disabled
* Post Script: Enabled
* Post Script Path: postscript.sh

For both the pre and post scripts, the script parameters should contain a comma separated list of file sets that need to be snapshotted for the paths included in the backup. For example, if the following two paths are included in the backup:

```bash
/mnt/Cohesity-fs1-fileset1/dir1/
/mnt/Cohesity-fs2-fileset2/
```

then the script parameters should be:

```bash
fs1/fileset1,fs2/fileset2
```

`Note`: there should be no spaces!

## Testing the Script

When the Cohesity Protection Group begins to run, the pre and post scripts will run at the begining and end of the backup, respectively. You can monitor the script output log on the GPFS node:

```bash
tail -f /tmp/cohesity-p*.log
```

The pre script will unmount/remount the mounts for each file set specified in the script parameters.

The post script will unmount after the backup has completed.
