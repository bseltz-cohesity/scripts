# Import Helios Detected Ransomware Anomalies into Power BI using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script imports detected ransomware anomalies from Helios into Power BI

## Components

* powerBI-helios-detectedAnomalies.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powerBI/python/powerBI-helios-detectedAnomalies/powerBI-helios-detectedAnomalies.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x powerBI-helios-detectedAnomalies
# end download commands
```

## Get a Helios API Key

Helios uses an API key for authentication. To acquire an API key:

1. log onto Helios
2. select 'All Clusters'
3. click settings -> access management -> API Keys
4. click Add API Key
5. enter a name for your key
6. click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again).

## Modify the Script

Edit the powerBI-helios-detectedAnomalies.py script and set the apiKey value to your Heios API key.

## Python Requirements

The following python modules are required to be installed on the computer running Power BI:

* requests
* pandas
* matplotlib

## Copy pyhesity.py into the Python Module Path

Find out where your user site directory location using the following command:

```bash
python -m site --user-site
```

Then ensure the directory location exists:

```bash
mkdir -p <user-site-location>
```

Finally, copy the pyhesity.py file to that location

## Setup the Data Source in Power BI

See [Run Python scripts in Power BI Desktop (docs.microsoft.com)](https://docs.microsoft.com/en-us/power-bi/connect-data/desktop-python-scripts) for more instructions on setting up Power BI to run python scripts.

1. In Power BI, click 'Get Data', select 'Python Script' and click connect.
2. Paste the modified contents of the powerBI-helios-detectedAnomalies.py script into the script box, and click OK.
3. Select the df element and click Load.
