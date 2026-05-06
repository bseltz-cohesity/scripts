# Running Cohesity Python Scripts

> **Disclaimer:** These scripts are provided on a best-effort basis and are not officially supported or sanctioned by Cohesity. The code is intentionally kept simple to serve as example code. Use at your own risk.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
  - [Python Version](#python-version)
  - [Installing the Requests Module](#installing-the-requests-module)
  - [Installing Without Internet Access](#installing-without-internet-access)
- [Running Scripts](#running-scripts)
- [Network Requirements](#network-requirements)
- [Downloading Scripts](#downloading-scripts)
- [The pyhesity Library](#the-pyhesity-library)
- [Authentication](#authentication)
  - [Username and Password](#username-and-password)
  - [Multi-Factor Authentication (MFA)](#multi-factor-authentication-mfa)
  - [API Key Authentication](#api-key-authentication)
- [Connecting to Cohesity](#connecting-to-cohesity)
  - [Direct Cluster Connection](#direct-cluster-connection)
  - [Connecting Through Helios (SaaS)](#connecting-through-helios-saas)
  - [Connecting Through Helios Self-Managed](#connecting-through-helios-self-managed)
- [Example: backupNow.py](#example-backupnowpy)
  - [Download](#download)
  - [Basic Usage](#basic-usage)
  - [Common Examples](#common-examples)
  - [Parameters Reference](#parameters-reference)
- [Password Storage](#password-storage)
- [Scheduling Scripts (Unattended Execution)](#scheduling-scripts-unattended-execution)
- [Troubleshooting](#troubleshooting)

---

## Overview

The Cohesity Python scripts use the Cohesity REST API to automate data protection tasks. Each script relies on a shared helper library called **`pyhesity.py`**, which handles authentication, API calls, and date formatting. Both files — the script and `pyhesity.py` — must be present in the same directory before running.

Scripts can be run from any laptop, desktop, or server that has network access to the Cohesity cluster (or Helios) and has Python and the `requests` module installed.

---

## Prerequisites

### Python Version

These scripts support any version of Python new enough to support TLSv1.2 encryption — Python 2.7 or later (including some later 2.6.x versions). Python 3.x is recommended.

### Installing the Requests Module

The `requests` module is not built into Python and must be installed separately. If it is missing, you will see:

```text
No module named 'requests'
```

**Linux and macOS:**

```bash
sudo pip install requests
# or
sudo pip3 install requests
# or
python -m pip install requests
# or
python3 -m pip install requests
```

If you have `easy_install`:

```bash
sudo easy_install -U requests
```

**Using a Linux package manager:**

```bash
# yum (RHEL/CentOS)
sudo yum install python-requests
sudo yum install python3-requests

# dnf (Fedora/RHEL 8+)
sudo dnf install python-requests
sudo dnf install python3-requests

# apt-get (Ubuntu/Debian)
sudo apt-get install python-requests
sudo apt-get install python3-requests
```

**Windows:**

```bash
pip install requests
# or
pip3 install requests
# or
python -m pip install requests
# or
python3 -m pip install requests
```

### Installing Without Internet Access

If the script host has no internet access, download the appropriate offline package from another machine and transfer it:

**RHEL 9 / Python 3.9.x:**

<https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/requests-3.9.18.tgz>

**RHEL 8 / Python 3.6.x:**

<https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/requests-3.6.8.tgz>

After transferring the `.tgz`, extract it, `cd` into the folder, then install:

```bash
# RHEL 9 / Python 3.9.x
pip3 install requests-2.31.0-py3-none-any.whl -f ./ --no-index

# RHEL 8 / Python 3.6.x
pip3 install requests-2.27.1-py2.py3-none-any.whl -f ./ --no-index
```

---

## Running Scripts

Each script's README explains its command line options and provides examples. The examples assume a Linux, macOS, or other Unix-like system where the script is directly executable:

```bash
./myscript.py -v mycluster -u myuser
```

This works only if `/usr/bin/env python` launches Python on your system. If it does not, prefix the command with `python` or `python3`:

```bash
python3 ./myscript.py -v mycluster -u myuser
```

On Windows, omit the leading `./`:

```bash
python3 myscript.py -v mycluster -u myuser
```

> **Note on line continuation:** The examples in this document use multi-line format with the `\` (backslash) line continuation character for readability. The `\` must be the very last character on the line — no trailing spaces — and there must be no blank lines between continued lines, or the command will end prematurely.

---

## Network Requirements

For a script to connect to a Cohesity cluster (or `helios.cohesity.com`), the host running the script must be able to:

- Resolve the hostname or IP passed to `-v` / `--vip`
- Reach the cluster on **port 443/tcp** (no firewall or routing should block this)
- Pass the Cohesity cluster's built-in firewall (**Settings → Networking → Firewall → Management** in the UI)

If any of these are not met, the script will appear to hang and eventually report a timeout, SSL, connection, or retry error. These errors are almost always network-related — not script bugs.

**To verify connectivity from a machine with a browser**, navigate to `https://mycluster`. If the Cohesity UI does not load, the requirements above are not met.

**To verify from the command line:**

```bash
curl -k https://mycluster
```

If curl returns HTML output, connectivity is working. If it returns an error, contact your network team to verify routing and firewall rules between the script host and the cluster.

---

## Downloading Scripts

Each script's README includes download commands using `curl`. Below is the general pattern for downloading any Python script and its required helper library:

```bash
# Download the main script
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/<scriptName>/<scriptName>.py

# Download the pyhesity helper library
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py
```

Place both files in the same directory before running the script.

---

## The pyhesity Library

`pyhesity.py` is a helper module that simplifies connecting to and using the Cohesity REST API. It provides:

- **Authentication functions** — connect to clusters, Helios (SaaS), or Helios Self-Managed
- **REST API wrappers** — GET, POST, PUT, DELETE calls
- **Date conversion utilities** — Cohesity stores dates as Unix Epoch Microseconds (UTC)

### Importing pyhesity in a script

```python
from pyhesity import *

# Authenticate to a cluster
apiauth('mycluster', 'admin')

# Authenticate with an Active Directory user
apiauth('mycluster', 'myuser', 'mydomain.net')
```

### Date utility examples

```python
# Convert a Cohesity timestamp (microseconds) to a readable date
usecsToDate(1533978038503713)
# Returns: '2018-08-11 05:00:38'

# Convert a readable date to Cohesity microseconds
dateToUsecs('2018-08-11 05:00:38')
# Returns: 1533978038000000

# Get a timestamp representing a point in the past
timeAgo('24', 'hours')
```

---

## Authentication

### Username and Password

On first run, the script will prompt you to enter your password. The password is then encrypted and stored in `~/.pyhesity` for future unattended use.

```bash
# Local user account
./backupNow.py -v mycluster.mydomain.net \
               -u myuser \
               -j myjob

# Active Directory user account
./backupNow.py -v mycluster.mydomain.net \
               -u myuser \
               -d mydomain.net \
               -j myjob
```

> **Note:** Use the fully-qualified domain name (e.g., `MYDOMAIN.NET`), not a short name (e.g., `MYDOMAIN`).

You may also pass the password on the command line (not recommended for security reasons):

```bash
./backupNow.py -v mycluster.mydomain.net \
               -u myuser \
               -pwd Sw0rdFish \
               -j myjob
```

### Multi-Factor Authentication (MFA)

If MFA is enabled for a user account, provide the OTP code using `--mfaCode`:

```bash
./backupNow.py -v mycluster.mydomain.net \
               -u myuser \
               -d mydomain.net \
               -j myjob \
               --mfaCode 417255
```

> **Note:** Because MFA codes change frequently, they cannot be used for scheduled/unattended scripts. Use API Key authentication for automated runs instead.

### API Key Authentication

API keys are static credentials that bypass MFA and password expiry, making them ideal for automation and scheduled tasks.

**To create an API key:**

1. Log in to Cohesity (or Helios) as the target user
2. Go to **Settings → Access Management → API Keys**
3. Click **Add API Key**, give it a name, and click **Save**
4. Copy the key immediately — it will not be shown again

**Using an API key (prompted):**

```bash
./backupNow.py -v mycluster.mydomain.net \
               -u myuser \
               -j myjob \
               --useApiKey
# Enter the API key when prompted for the password
```

**Using an API key (inline):**

```bash
./backupNow.py -v mycluster.mydomain.net \
               -u myuser \
               -j myjob \
               --useApiKey \
               -p xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## Connecting to Cohesity

### Direct Cluster Connection

Connect directly to a cluster by specifying its VIP (Virtual IP) or hostname. Requires port 443/tcp access. Both Username/Password and API Key authentication are supported.

```bash
./backupNow.py -v mycluster.mydomain.net \
               -u myuser \
               -j myjob
```

### Connecting Through Helios (SaaS)

Helios is Cohesity's SaaS management platform. When connecting through Helios, the VIP defaults to `helios.cohesity.com` and you must specify the cluster name to operate on. **Only API Key authentication is supported for Helios.**

> **Note:** Specify the short cluster name as listed in Helios, not the FQDN.

```bash
# API key entered when prompted
./backupNow.py -c mycluster \
               -u myuser \
               -j myjob

# API key provided inline
./backupNow.py -c mycluster \
               -u myuser \
               -j myjob \
               -p xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Connecting Through Helios Self-Managed

When connecting through Helios Self-Managed, specify both the Helios Self-Managed endpoint and the cluster name, along with the `-mcm` flag.

```bash
./backupNow.py -v mcm.mydomain.net \
               -c mycluster \
               -u myuser \
               -j myjob \
               -mcm

# API key provided inline
./backupNow.py -v mcm.mydomain.net \
               -c mycluster \
               -u myuser \
               -j myjob \
               -p xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
               -mcm
```

---

## Example: backupNow.py

`backupNow.py` triggers an immediate on-demand backup run for a specified protection job. It can optionally wait for the run to complete and report the result.

**Source:** [https://github.com/bseltz-cohesity/scripts/tree/master/python/backupNow](https://github.com/bseltz-cohesity/scripts/tree/master/python/backupNow)

### Download

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/backupNow/backupNow.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py
```

### Basic Usage

```bash
./backupNow.py -v mycluster \
               -u admin \
               -j 'My Protection Job'
```

### Common Examples

**Run a job and wait for completion:**

```bash
./backupNow.py -v mycluster \
               -u admin \
               -j 'My Protection Job' \
               -w
```

**Run a job for a specific object only:**

```bash
./backupNow.py -v mycluster \
               -u admin \
               -j 'My Protection Job' \
               -o myserver.mydomain.net \
               -w
```

**Run a full backup (override policy):**

```bash
./backupNow.py -v mycluster \
               -u admin \
               -j 'My Protection Job' \
               -backupType kFull
```

**Run with local-only backup (skip replication and archival):**

```bash
./backupNow.py -v mycluster \
               -u admin \
               -j 'My Protection Job' \
               --localOnly
```

**Run using API key authentication:**

```bash
./backupNow.py -v mycluster \
               -u myuser \
               -j 'My Protection Job' \
               --useApiKey \
               -p xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Run via Helios (SaaS):**

```bash
./backupNow.py -c mycluster \
               -u myuser \
               -j 'My Protection Job' \
               -p xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Parameters Reference

#### Connection Parameters

| Parameter | Short | Description |
| ----------- | ------- | ------------- |
| `--vip` | `-v` | Name or IP of the Cohesity cluster (defaults to `helios.cohesity.com`) |
| `--username` | `-u` | Username to authenticate with |
| `--domain` | `-d` | Active Directory domain (defaults to `local`) |
| `--password` | `-p` | Password or API key (prompted if omitted) |
| `--clusterName` | `-c` | Cluster name to select (used with Helios (SaaS) or Helios Self-Managed) |
| `--useApiKey` | `-i` | Use API key for authentication |
| `--mfaCode` | | TOTP MFA code |
| `--mcm` | | Connect through Helios Self-Managed |

#### Job Parameters

| Parameter | Short | Description |
| ----------- | ------- | ------------- |
| `--jobName` | `-j` | **Required.** Name of the protection job to run |
| `--objectName` | `-o` | Limit the run to a specific object within the job |
| `--backupType` | `-t` | Backup type: `kRegular`, `kFull`, `kLog`, or `kSystem` (default: `kRegular`) |

#### Policy Override Parameters

| Parameter | Description |
| ----------- | ------------- |
| `--localOnly` | Skip replication and archival; local backup only |
| `--noReplica` | Skip replication tasks |
| `--noArchive` | Skip archival tasks |
| `--keepLocalFor` | Override local snapshot retention (days) |
| `--replicateTo` | Override replication target cluster name |
| `--keepReplicaFor` | Override replica retention (days) |
| `--archiveTo` | Override archival target name |
| `--keepArchiveFor` | Override archive retention (days) |

#### Wait / Monitoring Parameters

| Parameter | Short | Description |
| ----------- | ------- | ------------- |
| `--wait` | `-w` | Wait for the job run to complete before exiting |
| `--progress` | | Show progress percentage while waiting |
| `--cancelActive` | | Cancel any currently active run before starting a new one |
| `--abortIfRunning` | | Exit without starting a new run if one is already in progress |
| `--timeout` | | Minutes to wait before timing out (default: 720) |

#### Output Parameters

| Parameter | Description |
| ----------- | ------------- |
| `--outputlog` | Write output to a log file |
| `--logfile` | Path to the log file (defaults to `log-backupNow.log` in script directory) |

---

## Password Storage

On the first successful authentication, `pyhesity.py` encrypts and stores the password in `~/.pyhesity`. On subsequent runs, the stored credential is used automatically, allowing scripts to run unattended without re-entering the password.

If the password changes, delete the stored credential or re-run the script — you will be prompted again. To update the stored password explicitly:

```python
from pyhesity import *
apiauth('mycluster', 'myuser', 'mydomain.net', updatepw=True)
```

---

## Scheduling Scripts (Unattended Execution)

For scheduled or unattended runs (e.g., cron jobs):

1. **Use API key authentication** — avoids MFA and password expiry issues
2. **Store the credential** on first interactive run so subsequent runs do not prompt
3. Use the `-p` flag to pass the API key inline if needed in non-interactive environments

**Example cron job (daily at 2am):**

```cron
0 2 * * * /usr/bin/python3 /opt/cohesity/backupNow.py \
  -v mycluster.mydomain.net \
  -u svc-cohesity \
  -j 'Nightly Backup' \
  --useApiKey \
  -p xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
  -w >> /var/log/cohesity-backup.log 2>&1
```

---

## Troubleshooting

| Symptom | Likely Cause | Resolution |
| --------- | ------------- | ------------ |
| Script hangs and never connects | Firewall blocking port 443/tcp | Verify connectivity with `ping` or `curl -k https://mycluster` |
| `Authentication failed` | Invalid credentials or user not registered | Confirm the user exists and has a role assigned in Access Management |
| `Authentication failed: MFA Code Required` | MFA enabled but no code provided | Add `--mfaCode <code>` or switch to API key authentication |
| `Please specify the mandatory parameters` | Older script version without MFA support | Update to the latest script version from the repository |
| Timeout errors | Cluster under heavy load or API rate limits reached | See [API Timeouts](https://github.com/cohesity/community-automation-samples/blob/main/doc/681-Upgrade-Impacts.md#api-timeouts) |
| `Too Many Requests` errors | API rate limiting | See [API Rate Limiting](https://github.com/cohesity/community-automation-samples/blob/main/doc/681-Upgrade-Impacts.md#api-rate-limiting) |
| SSO user authentication fails | SSO users are not supported | Use a local or Active Directory user account instead |

---

*For the latest versions of all scripts, visit: [https://github.com/cohesity/community-automation-samples](https://github.com/cohesity/community-automation-samples)*
