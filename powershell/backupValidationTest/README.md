# Validate Backups Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to download and check files from protected servers to validate that backups were successful. The script will report if checks failed or if the latest backup is more than 24 hours old. The script can be scheduled to run daily using the Windows task scheduler.  

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'backupValidationTest'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* backupValidationTest.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./backupValidationTest.ps1                                                                                                  
Connected!
getting MobaXterm.ini from w2012b.seltzer.net...
getting lsasetup.log from w2016...
getting jobMonitor.sh from centos1...

Server             Validation BackupAgeHours SLA
------             ---------- -------------- ---
w2012b.seltzer.net Successful              7 Met
w2016              Successful              8 Met
centos1            Successful              8 Met
```

To setup the script, configure the parameters and file list in the first two stanzas of the script like below:

```powershell
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'mycluster', #the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'admin', #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][string]$smtpServer = '192.168.1.95', #outbound smtp server 
    [Parameter()][string]$smtpPort = '25', #outbound smtp port
    [Parameter()][string]$sendTo = 'myaddress@mydomain.com', #send to address
    [Parameter()][string]$sendFrom = 'backuptest@mydomain.com' #send from address
)

### list of backed up files to check
$fileChecks = @(
    @{'server' = 'w2012b.seltzer.net'; 'fileName' = 'MobaXterm.ini'; 'expectedText' = '[Bookmarks]'};
      @{'server' = 'w2016'; 'fileName' = 'lsasetup.log'; 'expectedText' = '[11/28 08:45:36] 508.512>  - In LsapSetupInitialize()'};
      @{'server' = 'centos1'; 'fileName' = 'jobMonitor.sh'; 'expectedText' = '#!/usr/bin/env python'}
)
```
## Notes and Limitations

* files to be checked must be successfully indexed. Non-indexed files will display 'Check Failed' and an indexing backlog will cause the script to report an SLA violation. 

* the script supports physical and virtual Windows and linux servers






