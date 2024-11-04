# LVM Snapshot Pre and Post Scripts

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These bash scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of a Linux host to snapshot an LVM logical volume prior to the backup starting, and deleting the snapshot when the backup is complete.

Note: free space must be present in the volume group for a snapshot to be created.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/lv_snapper/prescript.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/lv_snapper/postscript.sh
chmod +x prescript.sh
chmod +x postscript.sh
# End download commands
```

## On the Linux Host

Install the Cohesity Agent. For example, on Linux you can install the Cohesity agent RPM:

```bash
yum localinstall el-cohesity-agent-6.6.0d_u2-1.x86_64.rpm
```

If a local firewall is running on the Linux host, ensure that port 50051/tcp is open for inbound connections from the Cohesity cluster.

Copy the pre and post scripts into `user_scripts` directory under the installation directory of the Cohesity agent, typically `/opt/cohesity/agent/software/crux/bin/user_scripts/` and make the scripts executable:

```bash
chmod +x prescript.sh
chmod +x postscript.sh
```

Modify the scripts to snapshot the volume group and logical volume on your host. In the example provided, the volume group is `centos` and the logical volume is `centos-root`.

## On the Cohesity Cluster

Register the Linux host as physical protection source

Create a physical file-based protection group

Select the Linux host to protect, and include any paths that you want to include in the backup. Note that the snapshot directory should be included in the path. For example, to backup `/home/myuser/`, the path should be:

```bash
/mny/root_snap/home/myuser/
```

Under the Additional Settings section of the protection group configuration, enable pre and post scripts, with the following settings:

* Pre Script: Enabled
* Pre Script Path: prescript.sh
* Continue Backup if Script Fails: Disabled
* Post Script: Enabled
* Post Script Path: postscript.sh
