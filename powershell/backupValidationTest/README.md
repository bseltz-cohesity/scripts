# Validate a Backup Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an instant volume mount, check the contents of a file, then tear down the mount. This can be scheduled to validate that a volume-based backup of a VM or physical server is good. It can also be scheduled to run daily using the Windows task scheduler.  

## Components

* backupValidationTest.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./backupValidationTest.ps1                                                                                                  
Connected!
latest backup occurred within the last 24 hours (12/06/2018 01:40:00)
mounting volumes to w2012a.seltzer.net...
Volume mounted successfully
Backup Validation Successful!
Tearing down mount points...
Process Complete
```

You can enter the following parameters at run time or hard code them into the script as shown below:

```powershell
param (
    [Parameter()][string]$vip = 'mycluster', #the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'admin', #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][string]$sourceServer = 'w2012b.seltzer.net', #source server that was backed up
    [Parameter()][string]$targetServer = 'w2012a.seltzer.net', #target server to mount the volumes to
    [Parameter()][string]$targetUsername = '', #credentials to ensure disks are online (optional, only needed if it's a VM with no agent)
    [Parameter()][string]$targetPw = '', #credentials to ensure disks are online (optional, only needed if it's a VM with no agent)
    [Parameter()][string]$testFile = 'C:\Users\myuser\Downloads\test.txt', #a file to check for on the backed up server
    [Parameter()][string]$testText = 'Hello World', #first line of text expected to be found in the test file
    [Parameter()][string]$smtpServer = '192.168.1.95', #outbound SMTP server to send results via email
    [Parameter()][string]$smtpPort = '25', #SMTP port
    [Parameter()][string]$sendTo = 'somebody@mydomain.com', #send results to
    [Parameter()][string]$sendFrom = 'backuptest@mydomain.com' #from address
)
```
## Notes and Limitations

* The script must be run from the machine that you've specified as the $targetServer. That way the backup volumes will be mounted to the local machine and the test file can be read.

* When validating the backup of a VMware VM, note that the $targetServer must also be a VM (VMDK backups can't be mounted to a physical server)

* When validating the backup of a physical server and you want to use a VM to run this script, you must register the VM as a physical server (a VM can be dual registered as a VM and as a physical server, no problem)

* This script is only designed to validate backups of Windows VMs/physical servers. Attempting to mount volumes from a Linux backup will fail.





