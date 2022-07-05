# Monitor Archive Tasks using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script monitors archive tasks. This is especially useful if have just started archiving and may have a back log that you may wish to monitor, or if you are archiving to a seed and ship device (e.g. AWS Snowball).

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'monitorArchiveTasks'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* monitorArchiveTasks.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./monitorArchiveTasks.ps1 -vip bseltzve01 -username admin -olderThan 0
```

```text
Connected!
searching for old snapshots...
found 7 snapshots with archive tasks
12/01/2018 04:07:00  CorpShare  (Archive kSuccessful)
12/02/2018 05:22:13  CorpShare  (Archive kSuccessful)
12/02/2018 11:24:02  Infrastructure  (Archive kSuccessful)
12/02/2018 11:26:07  VM Backup  (Archive kSuccessful)
12/03/2018 00:50:00  Infrastructure  (Archive kSuccessful)
12/03/2018 01:00:00  VM Backup  (Archive kSuccessful)
12/03/2018 02:10:00  CorpShare  (Archive kSuccessful)
```
