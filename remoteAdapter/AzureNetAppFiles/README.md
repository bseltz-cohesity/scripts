# Protect Azure NetApp Files with Cohesity Generic NAS Pre & Post Script

## Overview

Cohesity custom pre & post script for Azure NetApp Files, allows you to backup specific snapshots of Azure NetApp Files to Cohesity storage. Please note that this is tested and validated only for POC purposes.

### Prerequisites

Below is the list of prerequisites which should meet before configuring the Protection Group.
 Ensure that you have a Linux Control VM configured and have access to Azure NetApp Files volumes

1. Install PowerShell and required cmdlets
* Update the list of packages: 

  ```sudo apt-get update ```
*  Install pre-requisite packages: 

    ```sudo apt-get install -y wget apt-transport-https software-properties-common```
* Download the Microsoft repository GPG keys: 

  ```bash
  wget -q "https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb"
  # The version 20.04 was installed based on the Linux VM version. The scripts will work with any version that supports Az modules. 
  ```

* Register the Microsoft repository GPG keys: 

  ```sudo dpkg -i packages-microsoft-prod.deb```
* Update the list of packages: 

  ```sudo apt-get update```
* Upgrade the list of packages: 

  ```sudo apt-get upgrade```
* Install PowerShell: 

  ```sudo apt-get install -y powershell```
* Start PowerShell: 

  ```pwsh```
* Install Az modules (this will take up to 10-15 minutes)


	```Install-Module -AllowClobber -Name Az``` 

  ```Install-Module -AllowClobber -Name Az.NetAppFiles```

2. Prepare SSH access and scripts on Linux VM:

``` bash
# Log in to the Linux VM and enter the command 
cd .ssh 

```
  * Copy the SSH key from Protection Group Pre & Post Scripts section and Paste the copied SSH Key in the authorized_keys file.
``` bash
cat >> authorized_keys
# Press Contrl+D to save the file

```
  * Create a new directory called scripts in the Linux VM and create new files in it
``` bash 
mkdir scripts

```
  * Copy the scripts from the repository to the Linux VM's `scripts` folder

  * Change permissions on the created script files
  ``` bash
  chmod a+x *.ps1 
  ```


  3. Configure the Pre & Postscript in the Protection Group
  * In the Pre & Post Scripts, enable the Pre-Script toggle button.
  * In the Script Path, enter the full path of the create_anf_snapshots.ps1 file
In the Script Params, enter the params in the below format and replace the values with your Azure and Azure NetApp Files values except for the SnapshotName.
```bash
-AppID '7f2c948e-ffb4-4d49-ac24-66e5bbe3d8e5' -TenantID '75818451-2edd-4f92-8f36-47882b1a59b5' -SecretString '***your secret key value***' -ResourceGroupName 'cohesitywestus-rg' -Region 'westus' -AccountName 'anf' -PoolName 'cp' -VolumeName 'anfvol01' -SnapshotName 'coh_snap1'
# Update the values based on your Azure cloud and ANF configuration

```
 * In Pre & Post Scripts, enable the Post-Script toggle button.
* In the Script Path, enter the full path of the delete_anf_snapshots.ps1 file
 * In the Script Params, enter the params in the below format and replace the values with your Azure and Azure NetApp Files values except for the SnapshotName.
 ```bash
-AppID '7f2c948e-ffb4-4d49-ac24-66e5bbe3d8e5' -TenantID '75818451-2edd-4f92-8f36-47882b1a59b5' -SecretString '***your secret key value***' -ResourceGroupName 'cohesitywestus-rg' -AccountName 'anf' -PoolName 'cp' -VolumeName 'anfvol01' -SnapshotName 'coh_snap1'
# Update the values based on your Azure cloud and ANF configuration
```

### Run script

* The script will now run whenever the protection group is run

### Have any question

Send me an email at saran.ravi@cohesity.com
