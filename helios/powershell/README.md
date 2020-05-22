# Helios Access Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Components

* cohesity-api: the Cohesity REST API helper module

You can download the script using the following commands:

```powershell
# Download Commands
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

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

## Accessing Clusters via Helios

Authenticate:

```powershell
> . .\cohesity-api.ps1
> apiauth -helios
Connected!
```

List Helios clusters:

```powershell
heliosCluster
```

```text
name                     clusterId softwareVersion
----                     --------- ---------------
Cluster-01        8535175768906402 6.4.1a_release-20200127_bd2f17b1
co1               5405667779793465 6.3.1a_release-20190806_1ea88a62
cohesity-01       7627662926411335 6.4.1a_release-20200119_b7bdccc9
cohesity-agabriel 5933973227740175 6.4.1a_release-20200127_bd2f17b1
cohesity-c02      4695767953858364 6.4.1a_release-20200127_bd2f17b1
Cohesity-ENash    7913815271698841 6.4.1a_release-20200127_bd2f17b1
cohesity01        3828376101338092 6.5.0a_release-20200325_09322de5
```

Select a cluster to operate with:

```powershell
heliosCluster Cluster-01
```

And then use the API as usual:

```powershell
> foreach($job in (api get protectionJobs)){ $job.name }
```

```text
VPOC2-VM-BACKUP
NAS-Backup
ProtectSQLServer
SQLServerSystemDBs
SQL Physcial
VMSQLServer
MotorCity
HomeShares
```
