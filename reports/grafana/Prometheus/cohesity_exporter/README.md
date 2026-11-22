# Cohesity DataProtect Multi-Cluster Dashboard for Grafana (Prometheus)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Grafana dashboard displays the status of any number of Cohesity DataProtect clusters, connected directly or through Helios: storage capacity, node count and status, write throughput, the status of each protection group's last run, and open critical and warning alerts. A small Prometheus exporter queries the clusters and Prometheus stores the results, so no API key or sidecar web service is needed in Grafana.

The dashboard is driven by Grafana variables (data source, exporter job and cluster), so one dashboard covers the whole fleet, and a per-cluster section repeats once for each cluster you select.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/cohesity_exporter/cohesity_exporter.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/cohesity_exporter/cohesity_exporter_dashboard.json
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/cohesity_exporter/config.example.yaml
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/cohesity_exporter/requirements.txt
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/cohesity_exporter/cohesity_exporter.zip
# end download commands
```

## Components

* [cohesity_exporter_dashboard.json](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/cohesity_exporter/cohesity_exporter_dashboard.json) Grafana Dashboard JSON
* [cohesity_exporter.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/cohesity_exporter/cohesity_exporter.py) Prometheus exporter Python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py) Cohesity python function library
* [config.example.yaml](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/cohesity_exporter/config.example.yaml) exporter example config file
* [requirements.txt](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/cohesity_exporter/requirements.txt) python requirements
* [cohesity_exporter.zip](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/grafana/Prometheus/cohesity_exporter/cohesity_exporter.zip) full zip file

## Create a Prometheus Data Source in Grafana

If not already present, Configure the data source to point to your Prometheus instance, e.g. <http://localhost:9090>

## Setup the Prometheus Exporter

The exporter authenticates to each cluster (or to Helios), collects the metrics below, and refreshes its data in the background (every 60 seconds by default). Prometheus scrapes are served from this cache, so they are always fast and a slow cluster never delays the others.

Install the required python modules:

```bash
pip3 install -r requirements.txt
```

Create a config file from the example and list your clusters:

```bash
cp config.example.yaml config.yaml
```

```yaml
listen_port: 9792
scrape_interval: 60          # seconds between polls of each target
request_timeout: 30          # seconds per Cohesity API call
alerts_lookback_days: 7      # only count open alerts from the last N days
throughput_window_minutes: 15

clusters:
  # direct connection to a cluster VIP with a cluster API key
  - vip: cohesity-dc1.example.com
    api_key_env: COHESITY_DC1_API_KEY

  # Helios: one API key, many clusters
  - vip: helios.cohesity.com
    helios: true
    api_key_env: HELIOS_API_KEY
    # helios_clusters: [dc3, dc4]     # omit to export every registered cluster
```

Provide the API keys as environment variables and run the exporter:

```bash
export COHESITY_DC1_API_KEY=<cluster-api-key>
export HELIOS_API_KEY=<helios-api-key>
python3 cohesity_exporter.py --config config.yaml
```

### Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| -c, --config | Path to the YAML config file | config.yaml |
| -p, --port | Port to serve metrics on (overrides listen_port) | 9792 |
| -i, --interval | Seconds between polls (overrides scrape_interval) | 60 |
| -v, --verbose | Debug logging | off |

### Cluster Entries

| Key | Description | Default |
| --- | --- | --- |
| vip | Cluster VIP or DNS name, or helios.cohesity.com | required |
| api_key_env | Name of an environment variable holding the API key (preferred) | none |
| api_key | API key written directly in the file | none |
| name | Override the `cluster` label (direct clusters only) | the cluster's own name |
| helios | Set to true when vip is Helios | false |
| helios_clusters | Restrict a Helios entry to these cluster names | all registered clusters |
| username, domain | Passed to pyhesity (not used by API key authentication) | helios, local |

The API key only needs read access: CLUSTER_VIEW, PROTECTION_VIEW and ALERT_VIEW.

API keys are passed to pyhesity through an environment variable, so they are not written to `~/.pyhesity` or the pyhesity password file.

### Run as a Service

You can set up the exporter to run as a service:

example: /lib/systemd/system/cohesity-exporter.service

```bash
[Unit]
Description=Cohesity Prometheus Exporter Service
After=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/cohesity-exporter
EnvironmentFile=/etc/cohesity-exporter.env
ExecStart=/usr/bin/python3 /opt/cohesity-exporter/cohesity_exporter.py --config /opt/cohesity-exporter/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

example: /etc/cohesity-exporter.env (readable only by root)

```bash
COHESITY_DC1_API_KEY=<cluster-api-key>
HELIOS_API_KEY=<helios-api-key>
```

### Run in Docker

A Dockerfile is included:

```bash
cd exporter
docker build -t cohesity-exporter .
docker run -d -p 9792:9792 \
  -v $PWD/config.yaml:/etc/cohesity/config.yaml:ro \
  -e COHESITY_DC1_API_KEY=<cluster-api-key> \
  cohesity-exporter
```

### Add the Exporter to Prometheus

Add the exporter to your scrape configs in prometheus.yml:

```yaml
  - job_name: "cohesity"
    scrape_interval: 60s
    static_configs:
      - targets: ["localhost:9792"]
```

Validate and reload Prometheus (`promtool check config prometheus.yml`, then `kill -HUP $(pidof prometheus)` or `curl -X POST http://localhost:9090/-/reload` if started with `--web.enable-lifecycle`), then confirm the target is up under Status -> Targets.

## Import the Dashboard

In Grafana, go to Dashboards -> New -> Import and upload cohesity_exporter_dashboard.json. Select your Prometheus data source when prompted. The selection becomes the default for the dashboard's `datasource` variable, which you can still change later.

Dashboard variables:

| Variable | Description |
| --- | --- |
| datasource | Prometheus data source |
| job | Exporter job name (useful if you run more than one exporter) |
| cluster | One or more clusters, All by default |

Dashboard sections:

* **Fleet overview**: clusters up and down, nodes down, critical and warning alerts, failed last runs, total, used and free capacity, and a cluster summary table. Down or disconnected clusters are sorted to the top of the table with a red row.
* **Protection and alert detail**: last run status across the selected clusters and open alerts by category.
* **Cluster: (one per selected cluster)**: status, used %, free space, nodes down, alerts, failed groups, write throughput, storage and throughput trends, last run status, and a node table.

## Metrics

All cluster metrics carry a `cluster` label.

| Metric | Description |
| --- | --- |
| cohesity_up | 1 if the cluster API answered on the last poll, otherwise 0. Includes Helios clusters that are disconnected from Helios |
| cohesity_cluster_info | Always 1. Labels: cluster_id, version, cluster_type |
| cohesity_cluster_storage_total_bytes | Total storage capacity in bytes |
| cohesity_cluster_storage_used_bytes | Used storage in bytes |
| cohesity_cluster_storage_free_bytes | Available storage in bytes |
| cohesity_cluster_nodes | Number of nodes |
| cohesity_cluster_nodes_up | Number of nodes reporting up |
| cohesity_cluster_stopped_services | Number of stopped cluster services |
| cohesity_node_up | 1 if the node answered the cluster status request. Labels: node_id, node_ip, hostname |
| cohesity_node_maintenance_mode | 1 if the node is in maintenance mode |
| cohesity_node_marked_for_removal | 1 if the node is marked for removal |
| cohesity_node_offline_disks | Number of offline disks on the node |
| cohesity_node_upgrade_in_progress | 1 if an upgrade is in progress on the node |
| cohesity_cluster_write_throughput_bytes_per_second | Most recent cluster write throughput |
| cohesity_protection_groups_by_last_run_status | Protection groups grouped by the status of their last run. Label: status (Succeeded, SucceededWithWarning, Failed, Running, Canceled, Missed, Skipped, NoRun, and any other status the cluster reports) |
| cohesity_protection_groups | Total protection groups |
| cohesity_protection_groups_paused | Paused protection groups |
| cohesity_alerts | Open alerts. Label: severity (critical, warning or info) |
| cohesity_alerts_by_category | Open critical and warning alerts by category. Labels: category, severity. Zero counts are omitted |
| cohesity_exporter_collector_success | 1 if the collector succeeded on the last poll. Label: collector (storage, nodes, throughput, runs, alerts) |
| cohesity_exporter_poll_duration_seconds | How long the last poll of the cluster took |
| cohesity_exporter_last_success_timestamp_seconds | Unix time of the last successful poll |

Where the data comes from:

| Metric group | API endpoint |
| --- | --- |
| up, info | v1 `GET /public/cluster` |
| storage | v1 `GET /public/stats/storage` |
| nodes | v1 `GET /public/nodes` and `GET /public/cluster/status` |
| write throughput | v1 `GET /public/statistics/timeSeriesStats` (kNumBytesWritten) |
| protection groups | v2 `GET /data-protect/protection-groups?includeLastRunInfo=true` |
| alerts | v2 `GET /alerts-summary?statesList=kOpen` |

Behavior when something fails:

* An unreachable cluster, or a Helios cluster that is disconnected from Helios, reports `cohesity_up 0` and no other metrics, so stale values are never shown.
* If a single collector fails (for example alerts), only that collector's metrics are missing and `cohesity_exporter_collector_success{collector="alerts"}` is 0.
* Clusters are polled one after another. After the exporter starts, clusters appear as each one finishes, so a large fleet takes a little while to fill in. Later polls keep each cluster's last result until it is refreshed.

## Alerting

Example Prometheus alert rules:

```yaml
groups:
  - name: cohesity
    rules:
      - alert: CohesityClusterDown
        expr: cohesity_up == 0
        for: 10m
      - alert: CohesityStorageFull
        expr: 100 * cohesity_cluster_storage_used_bytes / cohesity_cluster_storage_total_bytes > 90
        for: 30m
      - alert: CohesityNodeDown
        expr: cohesity_node_up == 0
        for: 10m
      - alert: CohesityCriticalAlerts
        expr: cohesity_alerts{severity="critical"} > 0
        for: 15m
      - alert: CohesityCollectorFailing
        expr: cohesity_exporter_collector_success == 0
        for: 15m
      - alert: CohesityExporterStale
        expr: time() - cohesity_exporter_last_success_timestamp_seconds > 600
```

## Notes

Some behavior comes from the API specs and should be confirmed against your own clusters:

* **Node up** is inferred. The API has no per-node up/down flag, so a node is reported up when it appears in the cluster status response with `inCluster` true.
* **Write throughput** uses the same query as the earlier jsonExporter.py sample (`metricUnitType=5`, 180 second maximum rollup). The unit is not documented in the API spec; it is exported as bytes per second, so compare it with the Cohesity UI.
* **Open alerts** are requested with `statesList=kOpen` within the last `alerts_lookback_days` days (default 365). Compare the counts with the open alerts in the Cohesity UI.
* **Last run status** is read from `lastRun.localBackupInfo.status` of each protection group, falling back to `originalBackupInfo`. Groups that have never run are counted as `NoRun`.
* pyhesity keeps its connection in module-level state, so clusters are polled sequentially. Keep `scrape_interval` comfortably above the time a full poll takes (see `cohesity_exporter_poll_duration_seconds`).

## Testing Without a Cluster

`tests/mock_cohesity.py` (found in zip file) serves a small HTTPS mock of the endpoints above, and `tests/config.test.yaml` points the exporter at it. See the header of the mock for how to start it.
