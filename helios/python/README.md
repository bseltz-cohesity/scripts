# Helios Access Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script finds missed SLAs for recent job runs

## Components

* pyhesity.py: the Cohesity REST API helper module

You can download the script using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x slaMonitor.py
# end download commands
```

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

Please see here for more information: <https://github.com/bseltz-cohesity/scripts/tree/master/python#cohesity-rest-api-python-examples>

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key: 

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

If you enter the wrong password, you can re-enter the password like so:

```python
> from pyhesity import *
> apiauth(updatepw=True)
Enter your password: *********************
```

## Accessing Clusters via Helios

Authenticate:

```python
> from pyhesity import *
> apiauth()
Connected!
```

List Helios clusters:

```python
heliosCluster()
```

```text
ClusterID           SoftwareVersion                     ClusterName
---------           ---------------                     -----------
3245772218955543    6.4.1_release-20191219_aafe3274     BKDataRep01
5860211595354073    6.4.1_release-20191219_aafe3274     BKDRRep02
8535175768906402    6.4.1a_release-20200127_bd2f17b1    Cluster-01
5405667779793465    6.3.1a_release-20190806_1ea88a62    co1
6702215842292462    6.4.1a_release-20200127_bd2f17b1    Cohesity-02
5933973227740175    6.4.1a_release-20200127_bd2f17b1    cohesity-agabriel
4695767953858364    6.4.1a_release-20200127_bd2f17b1    cohesity-c02
7913815271698841    6.4.1a_release-20200127_bd2f17b1    Cohesity-ENash
3828376101338092    6.5.0a_release-20200325_09322de5    cohesity01
5062989141566444    6.4.1a_release-20200127_bd2f17b1    Cohesity03
8995224679629115    6.4.1a_release-20200127_bd2f17b1    CohesityENash-DR
8994431059110431    6.4.1a_release-20200127_bd2f17b1    eagle-01
7556253497086105    6.4_release-20190719_a66190e3       kCohesity-02
852096437357268     6.5_release-20200225_6b9ab358       MDB-180-65
1390512474667081    6.5_release-20200225_6b9ab358       MDB-200-65
4406074725720827    6.4.1a_release-20200127_bd2f17b1    Reid-VE-DR
728373022171039     6.4.1a_release-20200127_bd2f17b1    Reid-VE-HQ
3335856963778868    6.4.1a_release-20200127_bd2f17b1    selab2
6356366047902006    6.4.1a_release-20200127_bd2f17b1    selab3
867581370958123     6.5_release-20200225_6b9ab358       Squidward
1119844672076088    6.5_release-20200225_6b9ab358       ve-02
2585652671764202    6.4.0b_release-20191118_6cb6071e    ve189
5477145196389208    6.4.1a_release-20200127_bd2f17b1    vPOC2
```

Select a cluster to operate with:

```python
heliosCluster('vPOC2')
```

And then use the API as usual:

```python
> for job in api('get', 'protectionJobs'): print(job['name'])
```

```text
VPOC2-VM-BACKUP
NAS-Backup
ProtectSQLServer
SQLServerSystemDBs
SQL Physcial
VMSQLServer
MotorCity
HomeShares
```
