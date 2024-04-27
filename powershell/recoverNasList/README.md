# Recover a list of NAS Shares using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a list of protected NAS shares as Cohesity Views.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/recoverNasList/recoverNasList.ps1).content | Out-File recoverNasList.ps1; (Get-Content recoverNasList.ps1) | Set-Content recoverNasList.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [recoverNasList.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/recoverNasList/recoverNasList.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together. Create a text file for input, with the list of NAS UNC paths to recover, like so:

```text
\\mynas\share1
\\mynas\share1
\\mynas\share3
```

Then run the script like so:

```powershell
./recoverNasList.ps1 -vip mycluster 
                     -username myuser
                     -domain mydomain.net
                     -fullControl 'mydomain.net\domain admins'
                     -readWrite 'mydomain.net\group1', 'mydomain.net\group2'
                     -nasList .\nasList.txt
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -nasList: (optional) defaults to .\nasList.txt
* -fullControl: comma separated list of users to grant full control (share permissions)
* -readWrite: comma separated list of users to grant read/write (share permissions)
* -readOnly: comma separated list of users to grant read-only (share permissions)
* -modify: comma separated list of users to grant modify (share permissions)

## Notes

This example is for recovering SMB shares as SMB views. A number of settings are hard-coded into this example such as qos policy, SMB browsablility and access based enumeration.
