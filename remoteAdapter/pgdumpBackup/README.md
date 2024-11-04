# Backup PostgreSQL using pg_dump and a Remote Adapter Script

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script can be used as a pre-script in a remote adapter job to backup a PostgreSQL database.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/remoteAdapter/pgdumpBackup/backup.sh
chmod +x backup.sh
# End download commands
```

## Identify the Linux Host

Identify the IP address of the Linux host that will be running the rsync script. We will use this IP address in the Subnet Allowlist below. In RHEL/CentOS, you can type this command to get the IP address: ip a

Also identify a user account on the Linux host that will run the script. This user will need password-less sudo access to mount/unmount the Cohesity view. To grant this access, type: sudo visudo and append to the end of the file:  myuser ALL=(ALL) NOPASSWD: ALL

## Create a Cohesity View

1. In the Cohesity UI, click SmartFiles -> Views -> Create View
2. Select the Backup Target -> General view template
3. Enter a view name, e.g. myview, then click More Options
4. Expand the Security section and click Subnet Allowlist -> Add
5. To grant access to an IP address or subnet (including the Linux host IP address identified above), enter an IP address (e.g. 192.168.1.101/32) or an IP subnet (e.g. 192.168.0.0/16) and click add. Repeat steps 4 and 5 to add more
6. Click Create to finish creating the view
7. Click the three dots next to the new view, click Mount Paths and record the NFS mount path, e.g. mycluster.mydomain.net:/myview

## Mount the View on the Linux Host

1. Log on as the user we identified above
2. Make a directory to mount our view, e.g. sudo mkdir /mnt/myview
3. Set the permissions on the new directory, e.g. sudo chmod 777 /mnt/myview
4. Install NFS client, e.g. sudo yum install nfs-utils
5. Test mount the view, e.g. sudo mount mycluster.mydomain.net:/myview /mnt/myview
6. Unmount the view, e.g. sudo umount /mnt/myview

## Create and Modify the Script on the Linux Host

```bash
#!/bin/bash

sudo mount -t nfs -o soft,intr,noatime,retrans=1000,timeo=900,retry=5,rsize=1048576,wsize=1048576,nolock mycohesity.mydomain.net:/myview /mnt/myview/

rsync -rltov /some/data/thisfolder /mnt/myview --delete
rsync -rltov /other/data/thatfolder /mnt/myview --delete

sudo umount /mnt/myview/
```

1. Identify a location to create or download the script, e.g. /home/myuser
2. Set the permissions on the script: chmod +x backup.sh
3. Now test the script: ./backup.sh the script should mount the view, run pg_dump and unmount when finished.

## Create a Cohesity Remote Adapter Protection Group

Now we will create a protection group that will schedule the execution of the script and protect the view.

1. In the Cohesity UI, click Data Protection -> Protection -> Protect -> Remote Adapter
2. Enter a name for the protection group
3. Enter the Linux host IP or DNS name and the username we identified above
4. Copy the ssh public key shown, append the key to the /home/myuser/.ssh/authorized_keys file on the Linux host
5. Select a policy
6. Select the view we created above
7. Enter the full path to the script, e.g. `/home/myuser/backup.sh`
8. Enter the script parameters (-v viewpath), e.g. `-v mycluster.mydomain.net:/myview`
9. Specify a start time
10. Click Protect

## Test the Protection Group

1. In the Cohesity UI, click Data Protection -> Protection
2. Click on the protection group name
3. Click the three dots and click Run Now -> Run Now
4. Wait for the backup to start. You will see a new run appear. Click on the date of the new run.
5. Within the run, click on the view name. The pulse log will appear.
6. You should see text output of the script and successful completion.
