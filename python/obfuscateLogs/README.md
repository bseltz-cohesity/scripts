# Obfuscate Logs using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script will obfuscate the file paths (and other path-like strings) in log files. The script will unzip/re-zip and untar/tar gz and tar files.

Note: Minimum python version required - v3.2

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/obfuscateLogs/obfuscateLogs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x obfuscateLogs.py
# end download commands
```

## Components

* [obfuscateLogs.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/obfuscateLogs/obfuscateLogs.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py): the Cohesity REST API helper module

Place your log files in a folder (the script will process all files in that folder), then run the main script like so if you want to run it sequentially:

```bash
./obfuscateLogs.py -l ~/mylogs/
```

To run parallelly:

```bash
./obfuscateLogs.py -l ~/mylogs/ -p
```

To include custom rules:

```bash
./obfuscateLogs.py -l ~/mylogs/ -p -cr ./myrules.json
```

## Parameters

* -l, --logpath: path of folder containing logs (Required)
* -cr, --customrules: (optional) path to custom rules JSON file (see below)
* -f, --freespacemultiplier: (optional) multiple of free space required for logpath (defailt is 3)
* -p, --parallel: (optional) Launch parallel tasks for concurrent file processing
* -w, --workers: (optional) No. of concurrent processes to run if parallel processing is selected. If it is not provided with '-p' argument then it will default to the number of processors on the machine

## Custom Rules

You can provide custom rules (regex patterns) to search for. Create a JSON file with the custom rules like the below, then you can use the `-cr ./myfile.json` parameter to include the patterns to obfuscate.

```JSON
[
    {
        "pattern": "(?i)https://([\\w\\-\\.]+)|http://([\\w\\-\\.]+)",
        "description": "Generic web urls",
        "type": "redacted_url"
    },
    {
        "pattern": "\\b(?:(?:25[0-5]|2[0-4]\\d|1\\d{2}|[1-9]?\\d)\\.){3}(?:25[0-5]|2[0-4]\\d|1\\d{2}|[1-9]?\\d)\\b",
        "description": "ip address",
        "type": "redacted_ip"
    },
    {
        "pattern": "(?i)\\d{1,3}(?:\\.\\d{1,3}){3}\\s+[a-z0-9.-]+(?:\\s+[a-z0-9.-]+)*",
        "description": "etc hosts file",
        "type": "redacted_host"
    },
    {
        "pattern": "(?i)\\b(?:[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}|(?:[0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}|[0-9A-Fa-f]{4}\\.[0-9A-Fa-f]{4}\\.[0-9A-Fa-f]{4})\\b",
        "description": "General MAC address and Cisco-style",
        "type": "redacted_mac"
    }
]
```
