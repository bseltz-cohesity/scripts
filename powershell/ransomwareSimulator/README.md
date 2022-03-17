# Simulate Ransomware Attacks Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script generates and encrypts simulation files to trigger Helios/MCM ransomware anomaly detection. The script runs on Windows PowerShell (desktop edition) and can trigger alerts for any supported workload that can be written to locally or via mapped network drive from the local Windows host.

For example, you can run the script from a Windows host that is protected by Cohesity as a virtual machine or a physical host, and write the simulation files to the local disk to trigger detection for this host. Or, you can map a network drive to a NAS share that is protected by Cohesity to trigger detection for that NAS volume.

Note: that this script requires PowerShell Desktop Edition version 5.1 or later, but will not work on PowerShell Core.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'ransomwareSimulator'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -Uri "$repoUrl/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* ransomwareSimulator.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To trigger detection of the local machine, first ensure that this machine is protected by Cohesity. Ensure that the path that you choose to write the simulation files to is within scope of the backup (included and not excluded).

```powershell
./ransomwareSimulator.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobName 'my protection group' `
                          -objectName myservername
```

By default the script will create a directory called `ransomwareSimulatorData` in the current directory and will write approximately 1 GiB of data during the simulation, during which time, the protection group will run 15 times, ultimately triggering a ransomware anomaly detection in Helios.

To trigger detection of an SMB NAS volume, map a network drive to that NAS volume, again, ensuring that volume and path are within the scope of a backup, then you can specify the filePath, like so:

```powershell
./ransomwareSimulator.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobName 'my NetApp protection group' `
                          -objectName vol0 `
                          -filePath z:\
```

## Parameters

* -vip: (optional) Cohesity cluster or MCM to connect to (defaults to helios.cohesity.com)
* -username: (optional) Cohesity username (defaults to helios)
* -domain: (optional) Active Directory domain of user (defaults to local)
* -useApiKey: (optional) Use API key for authentication
* -password: (optional) will use stored password by default
* -mcm: (optional) connect via MCM
* -clusterName: (optional) required when connecting through Helios or MCM
* -jobName: name of protection group to run
* -objects: (optional) name of object to include in protection runs
* -filePath: (optional) path to write simulator files (default is current directory)
