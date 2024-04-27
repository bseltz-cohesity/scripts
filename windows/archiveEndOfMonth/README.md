# Archive an End Of Month Snapshot for Windows

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a compiled binary that archives an existing local snapshot taken on the last day of the month.

## Download The Binary

<https://github.com/cohesity/community-automation-samples/raw/main/windows/archiveEndOfMonth/archiveEndOfMonth.exe>

Run the tool like so:

```bash
# example
archiveEndOfMonth.exe -v mycluster -u myuser -d mydomain.net -j myjob1 -j myjob2 -k 365 -t S3
# end example
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: Name of protection job (repeat the -j parameter for multiple jobs)
* -k, --keepfor: keepfor X days
* -t, --targetname: name of the external target to archive to
