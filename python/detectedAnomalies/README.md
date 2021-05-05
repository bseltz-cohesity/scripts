# Report Helios Detected Ransomeware Anomalies Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script reports Helios Detected Ransomeware Anomalies over the past 30 days.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/detectedAnomalies/detectedAnomalies.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x detectedAnomalies.py
# end download commands
```

## Components

* detectedAnomalies.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./detectedAnomalies.py -u myusername
```

## Parameters

* -u, --username: username to authenticate to Cohesity cluster
