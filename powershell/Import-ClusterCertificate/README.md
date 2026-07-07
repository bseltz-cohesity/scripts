# Import Cohesity Cluster Certificate into Windows Trusted Root Store using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script pulls the CA/root certificate behind a Cohesity cluster's active web-serving (SmartFiles/Iris) certificate straight from the cluster's REST API and imports it into the local Windows Trusted Root/Intermediate CA stores -- replacing the manual process of generating a cert via iris_cli, saving it locally, and importing it into Trusted Root CAs by hand on the ADFR Management Server.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'Import-ClusterCertificate'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [Import-ClusterCertificate.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/Import-ClusterCertificate/Import-ClusterCertificate.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./Import-ClusterCertificate.ps1 -vip mycluster `
                                -username myusername `
                                -domain mydomain.net
```

Run it elevated (Run as Administrator) on the ADFR Management Server -- it writes to `Cert:\LocalMachine\Root`/`Cert:\LocalMachine\CA`, which requires admin rights.

## Modes

* **Full pipeline** (default): authenticates to the cluster and pulls trust material from `GET /webserver-certificate` and `GET /trusted-cas`, then imports it locally. This is the example above.
* **Import-only**: skip the cluster entirely and import a CA cert file you already have.

```powershell
./Import-ClusterCertificate.ps1 -caCertFile C:\certs\clusterCA.pem
```

## Authentication Parameters

* -vip: name or IP of Cohesity cluster
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code by email

## Other Parameters

* -caCertFile: (optional) path to an already-exported CA cert file (.pem/.cer) -- switches the script to import-only mode and skips the cluster API entirely
* -includeExpired: (optional) also import certs from `/trusted-cas` with a status other than "Valid" (default is to skip them)
* -outputFolder: (optional) where fetched/imported cert files are saved (defaults to .\certs)
* -showRawResponse: (optional) dump the raw JSON from `/webserver-certificate` and `/trusted-cas` for troubleshooting
* -dryRun: (optional) show what would be imported (subject, thumbprint, expiry, target store) without touching the cert store

## Notes

* If the cluster's active cert has no separate CA chain (self-signed, or CA-signed but the issuing chain was never uploaded back to the cluster), the script falls back to trusting the leaf cert itself. This pins the *current* cert -- if it's renewed/rotated, re-run this script against the new cert.
* Certs already present in the target store (matched by thumbprint) are skipped, so it's safe to re-run.
* `/trusted-cas` is what the cluster itself trusts for outbound connections (LDAP/KMS, etc.) -- it's checked as a bonus source, not the primary one. `/webserver-certificate` is what matters for ADFR to trust the cluster.
