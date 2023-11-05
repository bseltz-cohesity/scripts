# JSON API Cluster Stats Dashboard for Grafana

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Grafana dashboard displays backup success rates for a Cohesity cluster.

![dashboard](../../../../images/ClusterStats.png)

## Get the JSON File

Go here to get the raw JSON file and save it to your local machine.

<https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/reports/grafana/JSON-API/ClusterStats/Cluster-Stats-JSON-API.json>

## Create a JSON API Data Source in Grafana

Configure the data source to point to your InfluxDB instance, for example:

* URL: <https://localhost:8443/stats>
* Header: apiKey xxxxxxxxxxxxxxxxxxx
* Query String: vip=mycluster

## Setup a JSON Exporter to Capture Cohesity Cluster Stats

Here is an example JSON exporter that gets some time series stats from Cohesity

* [jsonExporter.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/reports/grafana/JSON-API/ClusterStats/jsonExporter.py)
* [pyhesity.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py)

You will also need to install the python modules flask and flask_cors

```bash
pip3 install flask
pip3 install flask_cors
```

You can setup the exporter to run as a service:

example: /lib/systemd/system/cohesity-jsonexporter.service

```bash
[Unit]
Description=Cohesity JSON Exporter Service

[Service]
Type=simple
WorkingDirectory=/usr/local/bin
ExecStart=/bin/bash /usr/local/bin/jsonExporter-start.sh

[Install]
WantedBy=multi-user.target
```

example: /usr/local/bin/jsonExporter-start.sh

```bash
#!/bin/bash
/usr/local/bin/scripts/python/jsonExporter.py
```

## Import the Dashboard

In Grafana, go to Dashboards -> Import and upload the JSON file. Give the new dashboard a unique name and UID, and select our data source.
