# Monitor Job Failures Across Helios Clusters using Powershell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script finds failed job runs

## Components

* heliosJobFaiures.ps1: the main python script
* cohesity-api.ps1: the Cohesity REST API helper module

You can download the scripts using the following commands:

```powershell
# Download Commands
$scriptName = 'heliosJobFailures'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/helios-other/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

Place both files in a folder together and run the main script like so:

```powershell
./heliosJobFailures.ps1
```

If you'd like to send the report via email, include the mail-related parameters:

```powershell
./heliosJobFailures.ps1 -smtpServer mysmtpserver -sendFrom myuser@mydomain.net -sendTo anotheruser@mydomain.net
```

```text
CLUSTER-01
  DSKWIN10 (PhysicalFiles) 3/27/20 1:00:01 AM
      192.168.1.4 (Cohesity service on host 192.168.1.4 cannot be reached . Please check connectivity to ...)

CO1
  WINTST (Physical) 3/29/20 8:05:00 AM
      WINSERVER1 (Connection failure to WinServer1 during the call GetAgentInfo)

COHESITY-ENASH
  AD-PROTECT (AD) 3/29/20 10:22:04 AM
      DC02 (Cohesity service on host DC02 cannot be reached . Please check connectivity to the service, i...)
  VM1 (VMware) 3/29/20 11:48:22 AM
      DC01 (The operation is not allowed in the current state.)
```

## Parameters

* -vip: (optional) DNS or IP of the Helios endpoint (defaults to helios.cohesity.com)
* -username: (optional) username to store helios API key (defaults to helios)
* -domain: (optional) domain of username to store helios API key (default is local)
* -smtpServer: (optional) SMTP gateway to forward email through
* -smtpPort: (optional) defaults to 25
* -sendfrom: (optional) email address to show in the from field
* -sendto: (optional) email addresses to send report to (use repeatedly to add recipients)

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

If you enter the wrong password, you can re-enter the password like so:

```powershell
> . .\cohesity-api.ps1
> apiauth -helios -updatePassword
Enter your password: *********************
```
