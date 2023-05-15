# Cohesity REST API PowerShell Example - Instant Volume Mount

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an Instant Volume Mount using PowerShell. The script takes a thin-provisioned clone of the latest backup of a server volume and attaches it to a server.

The script takes the following parameters:

* -vip: DNS or IP of the Cohesity Cluster
* -username:Cohesity User Name
* -domain: (optional) defaults to 'local'
* -sourceServer: source Server Name
* -targetServer: (optional) Server to attach to, defaults to same as sourceServer)
* -before: (optional) choose most recent backup before this date (e.g. '2023-05-15 00:00:00')

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'instantVolumeMount'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/tearDownVolumeMount.ps1").content | Out-File "tearDownVolumeMount.ps1"; (Get-Content "tearDownVolumeMount.ps1") | Set-Content "tearDownVolumeMount.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* instantVolumeMount.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
.\instantVolumeMount.ps1 -vip mycohesity -username admin -sourceServer server1.mydomain.net -targetServer server2.mydomain.net
Connected!
mounting volumes to server2.mydomain.net...
Task ID for tearDown is: 23404
D: mounted to F:\
lvol_2 mounted to G:\
C: mounted to H:\
```

## Tearing Down Mounts

Take note of the taskId reported in the output of the mount operation. You can use that to later tear down the mount, using the tearDownVolumeMount.ps1 script like so:

```powershell
./tearDownVolumeMount.ps1 -vip mycohesity -username admin -taskId 23404
Connected!
Tearing down mount points...
```

## Version Update

* Added monitoring for task completion
* Added mountPoint report
* Added taskId report for teardown
