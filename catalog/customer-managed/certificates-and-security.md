# Customer-Managed — Certificates & Security

[← Back to Customer-Managed](README.md)

Total scripts: **9**

## Reporting & Analytics (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [jobEncryptionReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/jobEncryptionReport) | Python | 2024-11-04 | This Python script generates a report of protection jobs and whether the storage targets are encrypted and outputs to HTML and CSV files. |

## User, Access & Security (8)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [cert.py](https://github.com/cohesity/community-automation-samples/tree/main/python/cert) | Python | 2025-04-03 | The script helps initialise certificate handling for clusters using multi-cluster registration or protecting HyperV data |
| [copyCerts.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/copyCerts) | PowerShell | 2026-10-22 | This PowerShell script copies the CA certificate chain and private key from one cluster to another, so that multi-cluster agent registration is possible. |
| [copyCerts.py](https://github.com/cohesity/community-automation-samples/tree/main/python/copyCerts) | Python | 2025-02-13 | This script copies the CA certificate chain and private key from one cluster to another, so that multi-cluster agent registration is possible. |
| [copySecurityConfig.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/copySecurityConfig) | PowerShell | 2025-02-25 | This PowerShell script copies the account security configuration from one cluster to another. |
| [generateAndUploadClusterCerts.py](https://github.com/cohesity/community-automation-samples/tree/main/python/generateAndUploadClusterCerts) | Python | 2025-03-07 | This script generates a new certificate from each primary cluster specificied (using the primary cluster's CA) and uploads the generated certificates to the target vault cluster, so that agents can registered with the target cluster. |
| [Import-ClusterCertificate.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/Import-ClusterCertificate) | PowerShell | 2026-07-07 | This PowerShell script pulls the CA/root certificate behind a Cohesity cluster's active web-serving (SmartFiles/Iris) certificate straight from the cluster's REST API and imports it into the local Windows Trusted Root/Intermediate CA stores -- replacing the manual process of generating a cert via iris_cli, saving it locally, and importing it into Trusted Root CAs by hand on the ADFR Management Server. |
| [uploadSSLCert.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/uploadSSLCert) | PowerShell | 2025-09-15 | This PowerShell script uploads SSL certificate and key to a Cohesity cluster. |
| [uploadSSLCertificate.py](https://github.com/cohesity/community-automation-samples/tree/main/python/uploadSSLCertificate) | Python | 2024-11-04 | This python script uploads and installs an SSL certificate and private key onto a Cohesity cluster. |
