# JSON API Cluster Stats Dashboard for Grafana

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Grafana dashboard displays some performance metrics for a Cohesity cluster.

![dashboard](../../../../images/ClusterStats.png)

## Get the JSON File

Go here to get the raw JSON file and save it to your local machine.

<https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/JSON-API/ClusterStats/Cluster-Stats-JSON-API.json>

## Create a JSON API Data Source in Grafana

Configure the data source to point to your InfluxDB instance, for example:

* URL: <https://localhost:8443/stats>
* Header: apiKey xxxxxxxxxxxxxxxxxxx
* Query String: vip=mycluster

## Setup a JSON Exporter to Capture Cohesity Cluster Stats

Here is an example JSON exporter that gets some time series stats from Cohesity

* [jsonExporter.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/JSON-API/ClusterStats/jsonExporter.py)
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py)

Note: the last line of jsonExporter.py contains the port and SSL sertificate files. You will need to create your own certificates, or remove the ssl_context parameter to make the script work.

```python
app.run(host='0.0.0.0', port=8443, ssl_context=('myhost_crt.pem', 'myhost_key.pem'))
```

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
cd /usr/local/bin/scripts/python/
/usr/local/bin/scripts/python/jsonExporter.py
```

## Import the Dashboard

In Grafana, go to Dashboards -> Import and upload the JSON file. Give the new dashboard a unique name and UID, and select our data source.
