# VSS Snapshot Pre and Post Scripts

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These Windows scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of a Windows host to create VSS snapshots of the volumes prior to the backup starting, and deleting the snapshots when the backup is complete.

Note: free space must be present on the volumes for snapshots to be created.

## Download the Files

<https://github.com/cohesity/community-automation-samples/raw/main/windows/vssSnapshot/prescript.cmd>
<https://github.com/cohesity/community-automation-samples/raw/main/windows/vssSnapshot/prescript.ps1>
<https://github.com/cohesity/community-automation-samples/raw/main/windows/vssSnapshot/postscript.cmd>
<https://github.com/cohesity/community-automation-samples/raw/main/windows/vssSnapshot/postscript.ps1>

## On the Windows Host

1. Install the Cohesity Agent

2. If a local firewall is running on the Linux host, ensure that port `50051/tcp` is open for inbound connections from the Cohesity cluster

3. Copy the scripts into the user_scripts directory under the installation directory of the Cohesity agent, typically `C:\Program Files\Cohesity\user_scripts`

4. Modify the cmd scripts if necessary to correct the paths if different from the typical path mentioned above

5. Modify the ps1 scripts if necessary to exclude any drives that you do not want to snapshot

## On the Cohesity Cluster

1. Register the Windows host as physical protection source

2. Create a physical file-based protection group

3. Select the Windows host to protect, and include any paths that you want to include in the backup. Note that the snapshot directory should be included in the path. For example, to backup `C:\Users\`, the path should be `C:\shadowcopy\Users\`

4. Under the Additional Settings section of the protection group configuration, enable pre and post scripts, with the following settings:

   * Pre Script: `Enabled`
   * Pre Script Path: `prescript.cmd`
   * Continue Backup if Script Fails: `Disabled`
   * Post Script: `Enabled`
   * Post Script Path: `postscript.cmd`
