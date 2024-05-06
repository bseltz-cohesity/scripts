# Protect Pure Flashblade Volumes using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script protects generic NAS volumes.

## Download the script

You can download the scripts using the following commands (using curl on Linux):

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectFlashblade/protectFlashblade.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectFlashblade/protectFlashblade-multi.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectFlashblade/flashBladeProtectionStatus.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectFlashblade.py
chmod +x protectFlashblade-multi.py
chmod +x flashBladeProtectionStatus.py
# end download commands
```

You can also use these PowerShell commands to download the files in Windows:

Run these commands from a terminal to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectFlashblade'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.py").content | Out-File "$scriptName.py"; (Get-Content "$scriptName.py") | Set-Content "$scriptName.py"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName-multi.py").content | Out-File "$scriptName-multi.py"; (Get-Content "$scriptName-multi.py") | Set-Content "$scriptName-multi.py"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/flashBladeProtectionStatus.py").content | Out-File "flashBladeProtectionStatus.py"; (Get-Content "flashBladeProtectionStatus.py") | Set-Content "flashBladeProtectionStatus.py"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/pyhesity.py").content | Out-File pyhesity.py; (Get-Content pyhesity.py) | Set-Content pyhesity.py
# End Download Commands
```

## Components

* [protectFlashblade.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectFlashblade/protectFlashblade.py): the main python script (creates one job for all selected volumes)
* [protectFlashblade-multi.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectFlashblade/protectFlashblade-multi.py): alternative that creates one job per volume
* [flashBladeProtectionStatus.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectFlashblade/flashBladeProtectionStatus.py): list protection status for all volumes of a flashblade
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place the files in a folder together and run the script like so:

To protect one or more volumes in a single (new or existing) protection job:

```bash
# example
./protectFlashblade.py -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -p 'My Policy' \
                       -j 'My New Job' \
                       -f flashblade1 \
                       -vol volume1 \
                       -vol volume 2 \
                       -t 'America/New_York' \
                       -ei \
                       -s '00:00' \
                       -is 180
# end example
```

To create a separate protection job for each volume:

```bash
# example
./protectFlashblade-multi.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \
                             -p 'My Policy' \
                             -f flashblade1 \
                             -l mycolumelist.txt \
                             -t 'America/New_York' \
                             -ei \
                             -s '00:00' \
                             -is 180
# end example
```

To get the current protection status for all volumes of a flashblade:

```bash
# example
./flashBladeProtectionStatus.py -v mycluster \
                                -u myuser \
                                -d mydomain.net \
                                -f flashblade1
# end example
```

Unprotected volume names will be output to a text file that can be used as the volume list for protectFlashblade-multi.py.

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: name of the job to make changes to (repeat paramter for multiple jobs)
* -p, --policyname: (optional) name of protection policy (only required for new job)
* -s, --starttime: (optional) start time for new job (default is '20:00')
* -i, --include: (optional) include path (default is /) repeat for multiple
* -n, --includefile: (optional) text file with include paths (one per line)
* -e, --exclude: (optional) exclude path (repeat for multiple)
* -x, --excludefile: (optional) text file with exclude paths (one per line)
* -t, --timezone: (optional) default is 'America/Los_Angeles'
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -ei, --enableindexing: (optional) enable indexing
* -vol, --volumename: (optional) generic volume to protect (repeat for multiple)
* -l, --volumelist: (optional) text file of volume names to protect (one per line)
* -c, --cloudarchivedirect: (optional) create cloud archive direct job
* -sd, --storagedomain: (optional) default is 'DefaultStorageDomain'
* -a, --allvolumes: (optional) protect all protectable volumes
* -z, --paused: (optional) pause new protection job
