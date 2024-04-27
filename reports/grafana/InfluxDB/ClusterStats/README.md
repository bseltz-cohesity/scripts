# InfluxDB Cluster Stats Dashboard for Grafana

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Grafana dashboard displays backup success rates for a Cohesity cluster.

![dashboard](../../../../images/ClusterStats.png)

## Get the JSON File

Go here to get the raw JSON file and save it to your local machine.

<https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/InfluxDB/ClusterStats/Cluster-Stats-InfluxDB.json>

## Create a InfluxDB Data Source in Grafana

Configure the data source to point to your InfluxDB instance, for example:

* URL: <http://localhost:9090>
* Organization: MyCompany
* Token: xxxxxxxxxxxxxxxx
* Default Bucket: cohesity

## Setup an InfluxDB Exporter to Capture Cohesity Cluster Stats

Here is an example InfluxDB exporter that gets some time series stats from Cohesity

* [influxdbClusterStatsExporter.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/InfluxDB/ClusterStats/influxdbClusterStatsExporter.py)
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py)

Note: the influxdbClusterStatsExporter.py contains some settings that you will need to update:

```python
token = 'BapMQGVqAJ4CQTVWYrACnfzBVNRfhFhtZanypjjMmySIPenGhe5u_EgOBJDVT7fECcsncgFuhiv56BptlQ-DLA=='
org = "MyCompany"
url = "http://localhost:8086"
bucket = "cohesity"
```

You will also need to install the python module influxdb_client

```bash
pip3 install influxdb_client
```

You can setup the exporter to run as a service:

example: /lib/systemd/system/cohesity-influxdb-exporter.service

```bash
[Unit]
Description=Cohesity InfluxDB Exporter Service

[Service]
Type=simple
WorkingDirectory=/usr/local/bin
ExecStart=/bin/bash /usr/local/bin/influx-start.sh

[Install]
WantedBy=multi-user.target
```

example: /usr/local/bin/influx-start.sh

```bash
#!/bin/bash
/usr/local/bin/scripts/python/influxClusterStatsExporter.py -v mycluster -u myuser 
```

## Import the Dashboard

In Grafana, go to Dashboards -> Import and upload the JSON file. Give the new dashboard a unique name and UID, and select our data source.
