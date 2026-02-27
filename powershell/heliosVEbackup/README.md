# Backup Helios Self-Managed Virtual Edition using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script shuts down Helios VMs, performs a backup and starts the VMs again.

`Warning:` This script is experimental, please work with your Cohesity representitives before attempting to use it. The script shuts down your Helios Self-Managed VMs, resulting in down time for Helios Self-Managed.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'heliosVEbackup'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'backupNow'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [heliosVEbackup.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/heliosVEbackup/heliosVEbackup.ps1): the main powershell wrapper script
* [backupNow.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/backupNow/backupNow.ps1): powershell script to run backups
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## Configuring the Scripts

Place all three script files in a folder together. Then edit the top sections of `heliosVEbackup.ps1` to match your environment:

```powershell
# vSphere parameters
$vCenter = 'myvcenter.mydomain.net'          # FQDN of your vCenter
$creds = Import-Clixml -Path .\mycreds.xml   # path to stored vCenter credentials (read below)
                                             # names of your Helios VMs
$vms = @(
    'my-helios-vm1',
    'my-helios-vm2',
    'my-helios-vm3',
    'my-helios-vm4'
)

# Cohesity cluster parameters
$cluster = 'mycohesitycluster.mydomain.net'  # FQDN of your Cohesity cluster (that bbacks up the VMs)
$username = 'myuser'                         # username to log into Cohesity cluster
$pg = 'myVMprotectionGroup'                  # name of protection group that protects the Helios VMs

# Helios parameters
$heliosEndpoint = 'myhelios.mydomain.net'    # FQDN of your Helios instance
$heliosUsername = 'admin'                    # username to log into Helios
```

## Powershell Requirements

This script requires PowerShell (should work fine on PowerShell desktop edition 5.1 or later, or PowerShell Core, on any supported operating system (e.g. Windows, Linux, Mac)).

vSphere PowerCLI is required (see: <https://techdocs.broadcom.com/us/en/vmware-cis/vcf/power-cli/latest/powercli/installing-vmware-vsphere-powercli.html>)

## Storing vCenter Credentials

As you can see in the script settings listed above, we specify a path to a vCenter stored credentials XML file, e.g.

```powershell
$creds = Import-Clixml -Path .\mycreds.xml
```

To create this stored credentials file, launch PowerShell and cd into the folder where the scripts are located, then type:

```powershell
$creds = get-credential
```

When prompted, enter the vCenter username (e.g. <administrator@vsphere.local>) and the password. Then save these credentials to an XML file:

```powershell
$creds | Export-Clixml -Path mycreds.xml
```

## Authenticating to Helios Self-Managed

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios Self-Managed
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

## Test the Script

`Warning:` when you run the script, Helios will shut down. Please consider testing off hours.

When ready to test the script, launch PowerShell, cd into the folder where the scripts are located, then type

```powershell
./heliosVEbackup.ps1
```

The script will do the following:

* Starts a log file (e.g. log-heliosVEbackup.txt)
* Connect to Helios (the fist time you run the script, you will be prompted for your API Key, this will be stored for later unattended use)
* Connect to vCenter
* Records the MAC addresses of the VMs to the log file
* Shutdown the Helios VMs
* Wait for shutdowns to complete
* Connect to the Cohesity cluster (the first time you run the script, you will be prompted for the password of your Cohesity user, this will be stored for later unattended use)
* Run the protection group that backs up the VMs
* Wait for protection run to finish
* Starts the VMs
* Waits for Helios to be responsive again

## Run the Script on a Schedule

After you have successfully tested the script, it can be scheduled to run in Windows Task Scheduler (or CRON on Linux).

For example, create a Windows Task Scheduler task that starts a program every night:

* Program/script: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
* Arguments: -command c:\scripts\powershell\heliosVEbackup.ps1
* Start In: c:\scripts\powershell

`Note:` vCenter credential XML is encrypted by the currenty logged on Windows user that created it, so the same Windows user must run the scheduled task (a different Windows user will not be ble to decrypt the password). Also, the API key and cohesity password that were stored (for later unattended use) when we tested the script - were stored in the current Windows user's registry. If we use a `different user` to run the scheduled task, then that user will not have these secrets stored in their registry, so the script will prompt for input in the background and will appear to be hung.

## Restoring Helios Self-Managed

To perform a restore, make sure the existing Helios VMs are shut down. Then we can restore `ALL` of the Helios VMs from a previous backup, using the Cohesity UI.

`Data Loss:` restoring Helios from a previous backup means that anything that occurred after the selected backup will be lost (e.g. reporting entries, access management and other operational configuration changes).

`Preserve MAC Addresses:` The restored VMs must use the same MAC addresses as the original Helios VMs, otherwise the network connections will fail. You can do one of the following:

* Use the "restore to alternate location" in the Cohesity UI, which lets you specify "preserve MAC address"
* If you "restore to original location" you may end up with new MAC addresses. In this case, you can refer to the backup log file which recorded the original MAC addresses, and use these to reconfigure the restored VMs.

`Copy Recovery vs Instant Recovery`: Copy Recovery is recommended, since these are large VMs, so the restore speed will benefit from the parallel restore tasks of Copy Recovery.
