# Extend Retention using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script extends the retention of existing snapshots. It can set new expiration dates for weekly, monthly and yearly snapshots.

## Components

* [extendRetention.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/extendRetention/extendRetention.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module
* [smtptool.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/extendRetention/smtptool.py): smtp functions to send email alerts

## Download The Scripts

```bash
# begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/extendRetention/extendRetention.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/extendRetention/smtptool.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x extendRetention.py
# end download commands
```

Place the files in a folder together and run the main script like so:

```bash
./extendRetention.py -s mycluster -u myusername -d mydomain.net \
                     -j 'SQL*' -j '*ackup' -wr 35 -w 6 -mr 365 -m 1 \
                     -ms mail.mydomain.net -mp 25 \
                     -to myuser@mydomain.com -fr someuser@mydomain.com
```

The script output should be similar to the following:

```text
Connected!
Job: File-Based Backup
    2019-06-23 00:40:00 extending retention to 2019-07-05 00:40:00
Job: SQL Backup
    2019-06-23 22:56:35 extending retention to 2019-07-05 22:56:35
    2019-06-23 16:56:34 extending retention to 2019-07-05 16:56:34
    2019-06-23 10:56:33 extending retention to 2019-07-05 10:56:33
    2019-06-23 04:56:32 extending retention to 2019-07-05 04:56:32
    2019-06-23 00:20:00 extending retention to 2019-07-05 00:20:00
Job: Scripts Backup
    2019-06-23 01:40:00 extending retention to 2019-07-05 01:40:00
Job: RMAN Backup
    2019-06-23 22:40:01 extending retention to 2019-07-05 22:40:01
Job: Utils Backup
    2019-06-23 08:58:00 extending retention to 2019-07-05 08:58:00
```

The output will also be written to a log file extendRetentionLog.txt and optionally sent to an email recipient.

## Parameters

* -s, --server: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobfilters: search pattern for job names (e.g. 'prod*', '\*dev\*', '*ackup')
* -y, --dayofyear: (optional) day of year to extend yearly snapshot (default is 1)
* -m, --dayofmonth: (optional) day of month to extend monthly snapshot (default is 1)
* -w, --dayofweek: (optional) day of week to extend weekly snapshot, Monday=0, Sunday=6 (default is 6)
* -yr, --yearlyretention: (optional)
* -mr, --monthlyretention: (optional)
* -wr, --weeklyretention: (optional)
* -ms, --mailserver: (optional) SMTP server address to send reports to
* -mp, --mailport: (optional) SMTP port to send reports to (default is 25)
* -to, --sendto: (optional) email address to send reports to
* -fr, --sendfrom: (optional) email address to send reports from
* -o, --offset: (optional) timezone offset (default is -8)
* -r, --includereplicas: (optional) extend retention of replicas also

## The Python Helper Module

The helper module, pyhesity.py, provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```

## A Note about Timezones

Cohesity clusters are typically set to US/Pacific time regardless of their physical location. If you schedule this script to run on a Cohesity cluster, make sure to account for the difference between your time zone and the cluster's timezone. For example, if you want to run the script at 5am eastern time, then schedule it to run at 2am on the cluster.

If you run the script on the cluster and want the script to offset dates to your local timezone, use the -o parameter. For example, if you are in the US eastern timezone, use -o -5

If on the otherhand, you are running the script on a server in your local timezone, you can omit the -o parameter.

## Schedule the Script to Run Weekly

We can schedule the script to run using cron.

```bash
crontab -e
```

Let's say that you want the script to run every Monday at 7am eastern. Remember to adjust to pacific time, which would be 4am. Enter the following line in crontab:

```text
0 4 * * 1 /home/cohesity/data/scripts/extendRetention.py -v mycluster -u myusername -d mydomain.net -j 'prod*' -j '*ackup' -wr 35 -w 6 -mr 365 -m 1 -ms mail.mydomain.net -mp 25 -to myuser@mydomain.com -fr someuser@mydomain.com
```
