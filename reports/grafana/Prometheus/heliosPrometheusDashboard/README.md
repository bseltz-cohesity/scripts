# Helios Cluster Status Dashboard for Grafana (Prometheus)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Grafana dashboard displays the status of all clusters registered to Helios: health, version, patch level, upgrade status, node count, capacity, and open alerts. A small Prometheus exporter queries Helios and Prometheus stores the results, so no API key or sidecar web service is needed in Grafana.

## Get the Files

Save these files to your local machine:

* [heliosPrometheusDashboard.json](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/heliosPrometheusDashboard/heliosPrometheusDashboard.json)
* [heliosPrometheusExporter.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/heliosPrometheusDashboard/heliosPrometheusExporter.py)
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py)

## Create a Prometheus Data Source in Grafana

Configure the data source to point to your Prometheus instance, e.g. <http://localhost:9090>

## Setup the Prometheus Exporter

The exporter authenticates to Helios, collects cluster status and open alerts, and refreshes its data in the background (every 5 minutes by default). Prometheus scrapes are served from this cache, so they are always fast.

Install the required python module:

```bash
pip3 install prometheus_client
```

Run the exporter using a Helios API key:

```bash
python3 heliosPrometheusExporter.py -i -pwd <your-helios-api-key> -port 1235
```

### Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| -v, --vip | Helios endpoint | helios.cohesity.com |
| -u, --username | Helios username | helios |
| -d, --domain | Helios user domain | local |
| -i, --useApiKey | Treat the password as an API key | off |
| -pwd, --password | Helios API key | none |
| -port, --port | Port to serve metrics on | 1235 |
| -a, --alertdays | Only count open alerts from the last N days | 7 |
| -r, --refreshseconds | Seconds between Helios refreshes | 300 |

### Run as a Service

You can set up the exporter to run as a service:

example: /lib/systemd/system/helios-prometheus-exporter.service

```bash
[Unit]
Description=Helios Prometheus Exporter Service

[Service]
Type=simple
WorkingDirectory=/usr/local/bin
ExecStart=/bin/bash /usr/local/bin/helios-exporter-start.sh

[Install]
WantedBy=multi-user.target
```

example: /usr/local/bin/helios-exporter-start.sh

```bash
#!/bin/bash
python3 /usr/local/bin/scripts/python/heliosPrometheusExporter.py -i -pwd <your-helios-api-key> -port 1235
```

Add the exporter to your scrape configs in prometheus.yml:

```yaml
  - job_name: "helios"
    scrape_interval: 60s
    static_configs:
      - targets: ["localhost:1235"]
```

Restart Prometheus, then confirm the target is up under Status -> Targets.

## Import the Dashboard

In Grafana, go to Dashboards -> New -> Import and upload heliosDashboardPrometheus.json. Give the new dashboard a unique name and UID, and select your Prometheus data source.

## Metrics

All cluster metrics carry a `cluster` label.

| Metric | Description |
| --- | --- |
| helios_cluster_info | Always 1. Labels: health, version, patch, upgrade_status |
| helios_cluster_connected | 1 if the cluster is connected to Helios, otherwise 0 |
| helios_cluster_health_state | 0 = Healthy, 1 = Critical, 2 = Unknown, 3 = Disconnected |
| helios_cluster_nodes | Number of nodes |
| helios_cluster_capacity_used_bytes | Used capacity in bytes |
| helios_cluster_capacity_total_bytes | Total capacity in bytes |
| helios_cluster_capacity_percent | Percent of capacity used |
| helios_cluster_open_alerts | Open alerts in the alert window. Label: severity (critical or warning) |
| helios_cluster_latest_alert_info | Always 1. Labels: severity, alert_name. Open critical alerts are preferred over warnings, newest first |
| helios_cluster_latest_alert_age_minutes | Age of the latest alert in minutes |
| helios_exporter_last_refresh_success | 1 if the last Helios refresh succeeded |
| helios_exporter_last_success_timestamp_seconds | Unix time of the last successful refresh |

Disconnected clusters report no nodes, capacity or alert metrics, and show a dash in the dashboard table.

## Alerting on Exporter Failures

If Helios authentication fails or Helios is unreachable, the exporter keeps serving its last good data. To be notified, alert on:

```text
helios_exporter_last_refresh_success == 0
```
