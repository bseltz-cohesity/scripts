# Update AWS External Target Credentials using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script updates the access key and secret key used to authenticate to an AWS S3 external target (for cloud archive or cloud tier).

## Download the script

```powershell
# Download Commands
$scriptName = 'updateAWSExternalTargetAccessKey'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [updateAWSExternalTargetAccessKey.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/updateAWSExternalTargetAccessKey/updateAWSExternalTargetAccessKey.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example
./updateAWSExternalTargetAccessKey.ps1 -vip mycluster `
                                       -username myusername `
                                       -domain mydomain.net `
                                       -targetName mytarget `
                                       -accessKey xxxxxxxxxxxxxxx `
                                       -secretKey yyyyyyyyyyyyyyyyyyyyy
# end example
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
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Required Parameters

* -targetName: name of the external target to update
* -accessKey: new access key to use
* -secretKey: new secret key to use

## Using a CSV File to Update Multiple Targets

You can create a CSV file like (let's call it targets.csv):

```text
vip,username,targetName,accessKey,secretKey
cluster1,admin,target1,AMFOEMOSNOTWLFR8BFRX,4lf04sBPf8rEfdpwnoifisn534osjfn3940nd0sn
cluster2,admin,target2,APFNEOFU60KSUFNSIRX4,lx7dmT0ejG93nsif/04jfK4nIl0rnsFesn32mwn3
```

and then run the script for each line in the CSV file like so:

```powershell
# example
$csv = Import-Csv -Path ./targets.csv
$csv | ForEach-Object{ ./updateAWSExternalTargetAccessKey.ps1 -vip $_.vip -username $_.username -targetName $_.targetName -accessKey $_.accessKey -secretKey $_.secretKey }
# end example
```
