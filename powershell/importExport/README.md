# Import and Export Cohesity Objects Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script exports various Cohesity objects to json files, to serve as documentation of cluster state and provide the possibility of re-importing some settings and objects for cluster rebuild or disaster recovery use cases.

Note that re-importing objects is non-trivial and requires complex logic for each object type that depends on the use case and the specific situation. Included here are scripts for re-importing storageDomains, protectionPolciies, Generic NAS sources and Generic NAS protection jobs. More to come on an as needed basis.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'importExport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/exportConfiguration.ps1").content | Out-File "exportConfiguration.ps1"; (Get-Content "exportConfiguration.ps1") | Set-Content "exportConfiguration.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/exportConfigurationV2.ps1").content | Out-File "exportConfigurationV2.ps1"; (Get-Content "exportConfigurationV2.ps1") | Set-Content "exportConfigurationV2.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/importStorageDomains.ps1").content | Out-File "importStorageDomains.ps1"; (Get-Content "importStorageDomains.ps1") | Set-Content "importStorageDomains.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/importPolicies.ps1").content | Out-File "importPolicies.ps1"; (Get-Content "importPolicies.ps1") | Set-Content "importPolicies.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/importNasSources.ps1").content | Out-File "importNasSources.ps1"; (Get-Content "importNasSources.ps1") | Set-Content "importNasSources.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/importNasJobs.ps1").content | Out-File "importNasJobs.ps1"; (Get-Content "importNasJobs.ps1") | Set-Content "importNasJobs.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* exportConfiguration.ps1
* importStorageDomains.ps1
* importPolicies.ps1
* importNasSources.ps1
* importNasJobs.ps1
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## Exporting Objects

Place all files in a folder together. You can run the exportConfiguration.ps1 script like so:

```powershell
./exportConfiguration.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -configFolder: (optional) Defaults to .\configExports

## Running the export script as a Scheduled Task

Please see the following PDF for tips on running this script using Windows Task Scheduler:
<https://github.com/cohesity/community-automation-samples/blob/main/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf>

## Importing Storage Domains

You can import storage domains like so. In this example, the source cluster was called mycluster and the target cluster is called drcluster:

```powershell
./importStorageDomains.ps1 -vip drcluster `
                           -username myusername `
                           -domain mydomain.net `
                           -configFolder .\configExports\mycluster
```

Note that any existing storage domains with the same name will not be imported.

## Importing Protection Policies

You can import storage domains like so. In this example, the source cluster was called mycluster and the target cluster is called drcluster:

```powershell
./importPolicies.ps1 -vip drcluster `
                     -username myusername `
                     -domain mydomain.net `
                     -configFolder .\configExports\mycluster
```

The policies will be imported with the name prefix "Imported from clusterName - ".

Note that only the local policy elements will be imported (no replication, archival, or cloud spin policy elements will be imported). This is because the remote clusters and external targets at the DR cluster will necessarily be differnt than the source cluster. Manual editing of the imported policies will be necessary to reestablish the copy targets.

## Importing Generic NAS Sources

You can import Generic NAS sources like so. In this example, the source cluster was called mycluster and the target cluster is called drcluster:

```powershell
./importNasSources.ps1 -vip drcluster `
                       -username myusername `
                       -domain mydomain.net `
                       -configFolder .\configExports\mycluster
```

For SMB sources, you will be prompted for the password for the specified SMB user.

## Importing Generic NAS Protection Jobs

You can import Generic NAS protection jobs like so. In this example, the source cluster was called mycluster and the target cluster is called drcluster:

```powershell
./importNasJobs.ps1 -vip drcluster `
                    -username myusername `
                    -domain mydomain.net `
                    -configFolder .\configExports\mycluster
```

The jobs will be imported with the name prefix "Imported from clusterName - ".
