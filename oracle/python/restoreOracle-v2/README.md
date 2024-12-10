# Restore an Oracle Database Using Python V2

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script performs an restore of an Oracle database. The script can restore the database to the original server, or a different server.

Note: this is a major rewrite of the previous restoreOracle.py script and may need significant testing to shake out any flaws. Please provide feedback if you try it out and find any issues.

## Components

* [restoreOracle-v2.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/restoreOracle-v2/restoreOracle-v2.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/restoreOracle-v2/restoreOracle-v2.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreOracle-v2.py
# end download commands
```

Place both files in a folder together and run the main script like so:

Restoring a DB to the original location:

```bash
./restoreOracle-v2.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -ss oracleprod.mydomain.net \
                      -sd proddb \
                      -l -w
```

Restoring a DB to an alternate location:

```bash
./restoreOracle-v2.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -ss oracleprod.mydomain.net \
                      -ts oracledev.mydomain.net \
                      -sd proddb \
                      -td resdb \
                      -oh /home/oracle/app/oracle/product/11.2.0/dbhome_1 \
                      -ob /home/oracle/app/oracle \
                      -od /home/oracle/app/oracle/oradata/resdb
                      -l -w
```

Restoring a PDB to the original location. Note: when restoring a PDB name, the source DB should be in the form of CDBNAME/PDBName:

```bash
./restoreOracle-v2.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -ss oracleprod.mydomain.net \
                      -sd CDB1/PDB1 \
                      -l -w
```

Restoring a PDB to an alternate location. Note: when restoring a PDB name, the source DB should be in the form of CDBNAME/PDBName:

```bash
./restoreOracle-v2.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -ss oracleprod.mydomain.net \
                      -sd CDB1/PDB1 \
                      -ts oracledev.mydomain.net \
                      -td PDB2 \
                      -tc CDB2 \
                      -oh /opt/oracle/product/19c/dbhome_1 \
                      -ob /opt/oracle \
                      -od /opt/oracle/oradata/PDB2 \
                      -l
```

Restore a CDB with two PDBs to an alternate location:

```bash
./restoreOracle-v2.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -ss oracleprod.mydomain.net \
                      -sd CDB1 \
                      -ts oracledev.mydomain.net \
                      -td CDB2 \
                      -pn PDB1 -pn PDB2 \
                      -oh /opt/oracle/product/19c/dbhome_1 \
                      -ob /opt/oracle \
                      -od /opt/oracle/oradata/CDB2 \
                      -l
```

Restoring an Oracle RAC DB:

```bash
./restoreOracle-v2.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -ss orascan1 -sd RacDB \
                      -ts orascan2 -td RacDB2 \
                      -oh /opt/oracle/product/19c/dbhome_1 \
                      -ob /opt/oracle \
                      -od /opt/oracle/oradata/RacDB2 \
                      -cn orarac1.mydomain.net \
                      -ch 4
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
* -e, --emailmfacode: (optional) send MFA code via email

## Basic Parameters

* -ss, --sourceserver: Server name where the database was backed up
* -sd, --sourcedb: Original database name
* -o, --overwrite: (optional) Overwrites an existing database (default is no overwrite)
* -ch, --channels: (optional) Number of restore channels
* -cn, --channelnode: (optional) RAC node to use for channels
* -w, --wait: (optional) wait for restore to finish and report result
* -pr, --progress: (optional) display percent complete
* -inst, --instant: (optional) perform instant recovery

## Container/Pluggable DB Parameters

* -pn, --pdbnames: (optional) PDBs to restore when restoring a CDB (default is all PDBs)
* -tc, --targetcdb: (optional) CDB to restore to when restoring a PDB

## Point in Time Parameters

* -lt, --logtime: (optional) Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -l, --latest: (optional) Replay the logs to the latest point in time available
* -n, --norecovery: (optional) Restore the DB with NORECOVER option (default is to recover)

## Alternate Destination Parameters

* -ts, --targetserver: (optional) name of target oracle server (default is sourceserver)
* -td, --targetdb: (optional) name of target oracle DB (default is sourcedb)
* -oh, --oraclehome: oracle home path on target (not required when overwriting original db)
* -ob, --oraclebase: oracle base path on target (not required when overwriting original db)
* -od, --oracledata: oracle data path on target (not required when overwriting original db)

## Advanced Parameters

* -nf, --nofilenamecheck: (optional) skip filename conflict check (use caution)
* -na, --noarchivelogmode: (optional) do not enable archive log mode on restored DB
* -nt, --numtempfiles: (optional) number of temp files
* -nc, --newnameclause: (optional) new name clause
* -nr, --numredologs: (optional) number of redo log groups
* -rs, --redologsizemb: (optional) size of redo log groups in MB (default is 20)
* -rp, --redologprefix: (optional) redo log prefix
* -bc, --bctFilePath: (optional) alternate bct file path
* -pf, --pfileparameter: (optional) one or more parameter names to include in pfile (repeat for multiple)
* -pl, --pfilelist: (optional) text file of pfile parameters (one per line)
* -cpf, --clearpfileparameters: (optional) delete existing pfile parameters
* -sh, --shellparameter (optional) one or more shell variable names (repeat for multiple)
* -dbg, --dbg: (optional) display api payload and exit (without restoring)
* -pi, --printinfo: (optional) print vip, source and target servers/databases to screen

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-l** parameter.

Or, if you want to replay logs to a specific point in time, use the **-lt** parameter and specify a date and time in military format like so:

```bash
-lt '2019-01-20 23:47:02'
```

## PFile Parameters

By default, Cohesity will generate a list of pfile parameters from the source database, with basic adjustments for the target database. You can override this behavior in a few ways.

* You can add or override individual pfile parameters using -pf (--pfileparameter), e.g. `-pf DB_RECOVERY_FILE_DEST_SIZE="32G"`
* You can provide a text file containing multiple pfile parameters using -pl (--pfilelist), e.g. `-pl ./myparams.txt`
* You can clear all existing pfile parameters and provide a complete pfile using -cpf (--clearpfileparameters) and -pl (--pfilelist), e.g. `-cpf -pl ./RESDB_pfile.txt`
