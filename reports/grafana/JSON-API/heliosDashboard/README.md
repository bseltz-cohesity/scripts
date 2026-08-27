# Helios Cluster Status Dashboard for Grafana

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Grafana dashboard displays a Helios cluster health and status table. It shows, for every cluster connected to Helios: connection/health state, software version and patch level, upgrade status, node count, capacity usage, and the most recent open critical or warning alert.

## Get the JSON File

Go here to get the raw JSON file and save it to your local machine.

<https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/JSON-API/HeliosDashboard/heliosDashboard.json>

## Create a JSON API Data Source in Grafana

Configure the data source to point to your exporter, for example:

* URL: `https://localhost:8444/clusterstatus`
* Header: `apiKey xxxxxxxxxxxxxxxxxxx`

The apiKey should be a Helios API key with access to the clusters you want reported on.

## Setup a JSON Exporter to Capture Cohesity Cluster Status

Here is an example JSON exporter that gets cluster status and alert data from Helios

* [heliosDashboardExporter.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/JSON-API/heliosDashboard/heliosDashboardExporter.py)
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py)

Note: the last line of `heliosDashboardExporter.py` contains the port and SSL certificate files. You will need to create your own certificates, or remove the `ssl_context` parameter to make the script work. It listens on port 8444 by default.

```python
app.run(host='0.0.0.0', port=8444, ssl_context=('myhost_crt.pem', 'myhost_key.pem'))
```

You will also need to install the python modules flask and flask_cors

```bash
pip3 install flask
pip3 install flask_cors
```

You can setup the exporter to run as a service:

example: /lib/systemd/system/cohesity-heliosdashboardexporter.service

```bash
[Unit]
Description=Cohesity Helios Dashboard Exporter Service

[Service]
Type=simple
WorkingDirectory=/usr/local/bin
ExecStart=/bin/bash /usr/local/bin/heliosDashboardExporter-start.sh

[Install]
WantedBy=multi-user.target
```

example: /usr/local/bin/heliosDashboardExporter-start.sh

```bash
#!/bin/bash
cd /usr/local/bin/scripts/python/
/usr/local/bin/scripts/python/heliosDashboardExporter.py
```

## Import the Dashboard

In Grafana, go to Dashboards -> Import and upload the JSON file. Give the new dashboard a unique name and UID, and select your data source.
