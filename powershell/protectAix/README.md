# Protect AIX Hosts using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds physical Aix servers to a file-based protection job. The script will automatically include the root path and will apply a list of exclusion paths to each server added to the job.

The script will overwrite existing exclusions, so make sure all desired exclusions are included in the exclusions list.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/protectAix/protectAix.ps1).content | Out-File protectAix.ps1; (Get-Content protectAix.ps1) | Set-Content protectAix.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/protectAix/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# end download commands
```

## Components

* protectAix.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module
* servers.txt: an optional text file containing a list of serversto add to the protection job
* exclusions.txt: a mandatory list of exclusion folder paths

Place all files in a folder together. Optionally create a text file called servers.txt and populate with the servers that you want to protect, like so:

```text
server1.mydomain.net
server2.mydomain.net
server3.mydomain.net
```

Note that the servers in the text file must be registered in Cohesity, and should match the name format as shown in the Cohesity UI.

Next create a text file called exclusions.txt and populate with the folder paths that you want excluded from every server in the job, like so:

```text
/dev
/proc
/var
/tmp
/lib
/lib64
/mnt
/media
/sys
/usr
```

Then, run the main script like so:

```powershell
./protectAix.ps1 -vip mycluster -username myusername -jobName 'My Job' -serverList ./servers.txt -exclusionList ./exclusions.txt
```

```text
Connected!
Processing servers...
  server1.mydomain.net
  server2.mydomain.net
  server3.mydomain.net
```

## Optional Parameters

* -domain: your AD domain (defaults to local)
* -server: name of a single server to add to the job
* -serverList: a text file list of servers to add to the job
