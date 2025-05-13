# List Registered Protection Sources using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script lists registered protection sources. Output is written to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'registeredSources'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [registeredSources.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/registeredSources/registeredSources.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

For a single cluster:

```powershell
./registeredSources.ps1 -vip mycluster -username myusername -domain mydomain
```

For multiple clusters (direct access/authentication):

```powershell
./registeredSources.ps1 -vip mycluster, mycluster2 -username myusername -domain mydomain
```

For all helios clusters:

```powershell
./registeredSources.ps1 -username myusername@mydomain.net
```

Email Report of all unhealthy sources for all Helios clusters:

```powershell
./registeredSources.ps1 -username myusername@mydomain.net -unhealthy -smtpServer smtp.mydomain.net -sendFrom me@mydomain.net -sendTo them@mydomain.net 
```

For selected helios clusters:

```powershell
./registeredSources.ps1 -username myusername@mydomain.net -clusterName mycluster, mycluster2
```

Search by source name (applies to all above scenarios):

```powershell
./registeredSources.ps1 -vip mycluster -username myusername -domain mydomain -searchString 'mysource1', 'mysource2'
```

Search by source type (applies to all above scenarios):

```powershell
./registeredSources.ps1 -vip mycluster -username myusername -domain mydomain -searchType 'vmware'
```

## Authentication Parameters

* -vip: (optional) one or more cluster names or IP (comma separated) defaults to helios.cohesity.com
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) one or more clusters (comma separated) to connect to when connecting through Helios or MCM

## Other Parameters

* -searchString: (optional) one or more source names or search strings (comma separated) to search for
* -searchList: (optional) text file of source names or search strings to search for (one per line)
* -searchType: (optional) limit results to sources where the environment type matches the search type
* -unhealthy: (optional) limit results to sources that have registration/health check errors
* -smtpServer: (optional) SMTP gateway to forward email through
* -smtpPort: (optional) SMTP port to use (default is 25)
* -sendTo: (optional) email addresses to send report to (comma separated)
* -sendFrom: (optional) email address to show in the from field
