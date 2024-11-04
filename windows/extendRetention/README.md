# Extend Retention for Windows

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a compiled binary that extends the retention of existing snapshots. It can set new expiration dates for weekly, monthly and yearly snapshots.

## Download The Binary

<https://github.com/cohesity/community-automation-samples/raw/main/windows/extendRetention/extendRetention.exe>

Run the tool like so:

```bash
# example
extendRetention.exe -s mycluster -u myusername -d mydomain.net -j "SQL*" -j "*ackup" -wr 35 -w 6 -mr 365 -m 1 -ms mail.mydomain.net -mp 25 -to myuser@mydomain.com -fr someuser@mydomain.com
# end example
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
