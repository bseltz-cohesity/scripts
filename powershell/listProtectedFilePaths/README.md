# List PRotected File Paths using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script lists included and excluded paths for physcal protection jobs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'listProtectedFilePaths'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* listProtectedFilePaths.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./listProtectedFilePaths.ps1 -vip mycluster `
                             -username myusername `
                             -domain mydomain.net
```

```text
Connected!

File-based Backup

    centos3.seltzer.net
      + /home/seltzerb (SkipNestedVolumes=True)
        - /home/seltzerb/junk

    centos5.seltzer.net
      + /home (SkipNestedVolumes=True)
        - /home/cohesityagent

Phys

    w2016t3.seltzer.net
      + /E/ (SkipNestedVolumes=True)
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
