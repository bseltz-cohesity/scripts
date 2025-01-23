# Backup Up File List for AIX

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a binary compiled for AIX that enumerates the files that are available for restore from the specified server/job. The file list is written to an output text file.

## Download the tool

Run these commands from a terminal to download the tool into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/aix/backedUpFileList/backedUpFileList
chmod +x backedUpFileList
# End download commands
```

## Examples

To list what versions are available:

```bash
./backedUpFileList -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -s server1.mydomain.net \
                   -j 'My Backup Job' \
                   -l
```

To use a specific job run ID:

```bash
./backedUpFileList -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -s server1.mydomain.net \
                   -j 'My Backup Job' \
                   -r 123456
```

To choose the backup at or after the specified file date:

```bash
./backedUpFileList -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -s server1.mydomain.net \
                   -j 'My Backup Job' \
                   -f '2020-06-30 13:00:00'
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication

## Mandatory Parameters

* -s, --sourceserver: name of server to inspect (repeat for multiple)
* -j, --jobname: name of protection job to run

## Other Parameters

* -l, --showversions: (optional) show available versions
* -t, --start: (optional) filter on versions after date
* -e, --end: (optional) filter on versions before date
* -r, --runid: (optional) use specific run ID
* -f, --filedate: (optional) date to inspect (next backup after date will be inspected)
* -p, --startpath: (optional) start listing files at path (default is /)
* -n, --noindex: (optional) do not use the index (otherwise index usage will be automatic)
* -f, --forceindex: (optional) force use the index (otherwise index usage will be automatic)
* -ss, --showstats: (optional) include last modified date and size (in bytes) in the output
* -nt, --newerthan: (optional) show files added/modified in the last X days
