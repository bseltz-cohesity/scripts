# Cohesity Job Monitor

Warning: this code is provided on a best effort basis by some dude and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple (hard coded stuff, lack of error checking) to retain value as example code (not to mention I was in a hurry). The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script monitors a Cohesity protection job and sends email alerts when the job starts and ends, along with the result (success, failed, canceled, etc).

## Components

* jobMonitor.sh: the main python script
* pyhesity.py: the Cohesity API module
* cohesity-jobmonitor.service: systemd unit file
* lastrun: records last run datetime

## pyhesity.py

pyhesity.py contains a group of functions that makes it easy to make REST API calls to a Cohesity cluster. Secure connections to Cohesity require TLS 1.2, so that generally means that pyhesity.py will only work on systems with a relatively recent version of python and OpenSSL, such as RHEL/CentOS 7 and recent versions of 6.x. That said, the job monitor can be deployed anywhere, so it should be easy to find or build a VM where it will run.

pyhesity.py uses the python requests module. You can install this on your system using one of the following:

```bash
sudo yum install python-requests
```
or
```bash
sudo easy_install requests
```

pyhesity.py can reside in the same folder as the jobMonitor.sh script, or you can intall it in your python module path like so:

```bash
mkdir -p `python -m site --user-site`
cp pyhesity.py `python -m site --user-site`
```

## jobMonitor.sh

Make sure to set this file as executable:

```bash
chmod +x jobMonitor.sh
```

jobMonitor.sh will require some customization to work in your environment. Near the top of the script you will find some constants that should be set for your environment:

```python
VIP = '192.168.1.198' #DNS or IP of the Cohesity cluster
USERNAME = 'admin' #Cohesity username
DOMAIN = 'local' #Cohesity domain
JOBNAME = 'VM Backup' #Cohesity protection job name
SLEEPTIME = 15 #seconds
FROMADDR = 'jobMonitor@mydomain.net' #email address for from field
TOADDR = 'unixguy@mydomain.com' #email address to send to
RUNFOLDER = '/home/myusername/' #folder where script is deployed
```

Also please review the sendMessage() function in the script. It is responsible for sending emails to an SMTP server. In my test environment, I have postfix running, so I could simply connect to my postfix server over port 25, unauthenticated. This code may need to be adjusted if your SMTP server requires authentication and/or secure connections.

You may notice that there's nowhere to enter the Cohesity password. When a user first tries to authenticate to a Cohesity cluster, you will be prompted for your password. The password will be stored in an encrypted file (under /home/username/.pyhesity) for later use (so that your script will run unattended). So, run jobMonitor.sh interactively once before trying to run it as a daemon. Note that you should run the script interactively as root (the same user that the daemon will run as).

## cohesity-jobmonitor.service

This is a systemd unit file to run the job monitor as a daemon. Supply the correct path to the jobMonitor.sh

```bash
Description=Cohesity Job Monitor Service
[Unit]
After=network.target

[Service]
Type=simple
ExecStart=/home/myusername/jobMonitor.sh

[Install]
WantedBy=multi-user.target
```

then copy cohesity-jobmonitor.service to `/lib/systemd/system` and run the following commands:

```bash
systemctl enable cohesity-jobmonitor.service
systemctl start cohesity-jobmonitor.service
systemctl status cohesity-jobmonitor.service
```


