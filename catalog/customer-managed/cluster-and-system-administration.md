# Customer-Managed — Cluster & System Administration

[← Back to Customer-Managed](index.md)

Total scripts: **49**

## Cluster & System Administration (18)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [cluster-manager-proxy.py](https://github.com/cohesity/community-automation-samples/tree/main/html/cluster-manager) | Python | 2026-09-16 | This is a web-browser-based Cohesity cluster manager. It combines two tools behind a single login session and a single tabbed UI: |
| [clusterHealthAudit.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/clusterHealthAudit) | Python | 2024-11-04 | This Python script gets cluster details including storage domains, interfaces and gflags. |
| [clusterInfo.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterInfo) | PowerShell | 2026-07-29 | This PowerShell script collects Cluster and Node configuration info. |
| [clusterInfo.py](https://github.com/cohesity/community-automation-samples/tree/main/python/clusterInfo) | Python | 2025-12-10 | This script collects cluster and node information. |
| [influxdbClusterStatsExporter.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/grafana/InfluxDB/ClusterStats) | Python | 2024-11-04 | This Grafana dashboard displays some performance metrics for a Cohesity cluster. |
| [jsonExporter.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/grafana/JSON-API/ClusterStats) | Python | 2026-08-19 | This Grafana dashboard displays some performance metrics for a Cohesity cluster. |
| [licenseCluster.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/licenseCluster) | PowerShell | 2024-11-04 | This powershell script generates a license and applies it to a cluster |
| [maintenance.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/maintenance) | PowerShell | 2026-08-12 | This powershell script starts or ends maintenance mode on protection sources. |
| [maintenance.py](https://github.com/cohesity/community-automation-samples/tree/main/python/maintenance) | Python | 2026-08-12 | This script starts or ends maintenance mode on protection sources. |
| [mutualCiphers.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/mutualCiphers) | PowerShell | 2026-06-23 | This PowerShell script finds TLS ciphers that are supportd by both the local Windows client and a Cohesity cluster. |
| [pingCluster.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pingCluster) | Python | 2024-11-04 | This python script pings the node IP and ipmi IP of each node in the cluster. |
| [prometheusClusterStatsExporter.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/grafana/Prometheus/ClusterStats) | Python | 2025-05-06 | This Grafana dashboard displays some performance metrics for a Cohesity cluster. |
| [reLicenseCluster.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/reLicenseCluster) | PowerShell | 2024-11-04 | *Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.* |
| [remoteIPs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/remoteIPs) | PowerShell | 2024-11-04 | This powershell script adds or removes IP addresses from a remote cluster configuration. |
| [testupgrade.sh](https://github.com/cohesity/community-automation-samples/tree/main/python/upgradeCluster) | Bash/Shell | 2024-11-04 | This python script initiates an upgrade of a Cohesity cluster to a newer version. |
| [upgradeCluster.py](https://github.com/cohesity/community-automation-samples/tree/main/python/upgradeCluster) | Python | 2024-11-04 | This python script initiates an upgrade of a Cohesity cluster to a newer version. (the main python script) |
| [upgradeServer.py](https://github.com/cohesity/community-automation-samples/tree/main/python/upgradeCluster) | Python | 2024-11-04 | This python script initiates an upgrade of a Cohesity cluster to a newer version. |
| [vipsLeastBusy.py](https://github.com/cohesity/community-automation-samples/tree/main/python/vipsLeastBusy) | Python | 2024-11-04 | This script gets a list of cluster VIPs sorted by CPU usage |

## Cluster Configuration (10)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [addRemoteCluster.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addRemoteCluster) | PowerShell | 2024-11-04 | This powershell script establishes replication between two Cohesity clusters. |
| [addVlan.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addVlan) | PowerShell | 2024-11-04 | This script adds a VLAN to the networking configuration of a Cohesity cluster. (the main powershell script) |
| [featureFlags.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/featureFlags) | PowerShell | 2024-11-04 | This PowerShell script gets, sets, exports and imports feature flags. |
| [featureFlags.py](https://github.com/cohesity/community-automation-samples/tree/main/python/featureFlags) | Python | 2024-11-04 | This python script gets, sets, exports and imports feature flags. |
| [firewallTool.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/firewallTool) | PowerShell | 2025-12-05 | This script adds/removes CIDR addresses from the firewall allow list of the specified service profile. |
| [firewallTool.py](https://github.com/cohesity/community-automation-samples/tree/main/python/firewallTool) | Python | 2025-06-12 | This python script adds/removes CIDR addresses from the firewall allow list of the specified service profile. |
| [gflagList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/gflagList) | PowerShell | 2026-09-01 | This powershell script lists available gflags for the specified service. |
| [gflagList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/gflagList) | Python | 2025-03-04 | This python script lists all of the available gflags for a service, and ouputs to the screen and to a text file. |
| [gflags.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/gflags) | PowerShell | 2026-06-06 | This powershell script gets, set, clears and imports gflags. |
| [gflags.py](https://github.com/cohesity/community-automation-samples/tree/main/python/gflags) | Python | 2026-04-16 | This python script gets, sets and imports gflags. |

## Cluster Create (17)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [clusterCreate-test.sh](https://github.com/cohesity/community-automation-samples/tree/main/python/clusterCreate) | Bash/Shell | 2024-11-04 | This Python script performs a cluster create, applies a license key and accepts the end-user license agreement, leaving the new cluster fully built and ready for login. (example command line) |
| [clusterCreate.py](https://github.com/cohesity/community-automation-samples/tree/main/python/clusterCreate) | Python | 2024-11-04 | This Python script performs a cluster create, applies a license key and accepts the end-user license agreement, leaving the new cluster fully built and ready for login. (the main python script) |
| [clusterCreateAndConfigVE.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterCreateAndConfigVE) | PowerShell | 2024-11-04 | This PowerShell script performs cluster create and sets various post create configuration options for a single-node virtual edition of Cohesity. (the main PowerShell script) |
| [clusterCreateVE.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterCreateAndConfigVE) | PowerShell | 2024-11-04 | This PowerShell script performs cluster create and sets various post create configuration options for a single-node virtual edition of Cohesity. (Only performs the cluster create part) |
| [cohesity-deploy-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deployCVE) | PowerShell | 2024-11-04 | This PowerShell script deploys a multi-node Cohesity Virtual Edition (VE) cluster on VMware vSphere. After deploying the OVA, the script performs the cluster setup, applies a license key and accepts the end-user license agreement, leaving the new cluster fully built and ready for login. |
| [configVE.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterCreateAndConfigVE) | PowerShell | 2024-11-04 | This PowerShell script performs cluster create and sets various post create configuration options for a single-node virtual edition of Cohesity. (the main PowerShell script) |
| [deployCVE.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deployCVE) | PowerShell | 2024-11-04 | This PowerShell script deploys a multi-node Cohesity Virtual Edition (VE) cluster on VMware vSphere. After deploying the OVA, the script performs the cluster setup, applies a license key and accepts the end-user license agreement, leaving the new cluster fully built and ready for login. (the main PowerShell script) |
| [deployCVEcluster.py](https://github.com/cohesity/community-automation-samples/tree/main/python/deployCVE) | Python | 2024-11-04 | This script may not work on Python 3 on Windows as there seem to be some issues with pyvmomi. This script was tested on CentOS 7.6 running Python 2.7.5. (the main python script) |
| [deployHSM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deployHSM) | PowerShell | 2026-03-16 | This powershell script deploys Helios Self-Managed OVAs to VMware and builds a Helios cluster. |
| [deployVE.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deployVE) | PowerShell | 2025-03-10 | This PowerShell script deploys a single-node Cohesity Virtual Edition (VE) appliance on VMware vSphere. After deploying the OVA, the script performs the cluster setup, applies a license key and accepts the end-user license agreement, leaving the new cluster fully built and ready for login. |
| [example-clusterCreateAndConfig.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterCreateAndConfigVE) | PowerShell | 2024-11-04 | This PowerShell script performs cluster create and sets various post create configuration options for a single-node virtual edition of Cohesity. (example syntax) |
| [example-clusterCreateAndConfigVE.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterCreateAndConfigVE) | PowerShell | 2024-11-04 | This PowerShell script performs cluster create and sets various post create configuration options for a single-node virtual edition of Cohesity. (example syntax) |
| [example-clusterCreateVE.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterCreateAndConfigVE) | PowerShell | 2024-11-04 | This PowerShell script performs cluster create and sets various post create configuration options for a single-node virtual edition of Cohesity. (example syntax) |
| [example-configVE.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterCreateAndConfigVE) | PowerShell | 2024-11-04 | This PowerShell script performs cluster create and sets various post create configuration options for a single-node virtual edition of Cohesity. (example syntax) |
| [nodeAdd.py](https://github.com/cohesity/community-automation-samples/tree/main/python/nodeAdd) | Python | 2024-11-04 | This python script adds a free node to a cluster. |
| [nodeRemove.py](https://github.com/cohesity/community-automation-samples/tree/main/python/nodeRemove) | Python | 2024-11-04 | This python script removes a node from a cluster. Before proceeding, the script will check that: |
| [test-deployCVE.sh](https://github.com/cohesity/community-automation-samples/tree/main/python/deployCVE) | Bash/Shell | 2024-11-04 | This script may not work on Python 3 on Windows as there seem to be some issues with pyvmomi. This script was tested on CentOS 7.6 running Python 2.7.5. (example command line) |

## Cluster State (4)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [serviceManager.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/serviceManager) | PowerShell | 2024-11-04 | This powershell script starts, stops and restarts cluster services. |
| [startCluster.py](https://github.com/cohesity/community-automation-samples/tree/main/python/startCluster) | Python | 2024-11-04 | This script starts the Cohesity cluster services. |
| [startStopCluster.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/startStopCluster) | PowerShell | 2024-11-04 | This PowerShell script starts and stops the cluster. |
| [stopCluster.py](https://github.com/cohesity/community-automation-samples/tree/main/python/stopCluster) | Python | 2024-11-04 | This script stops the Cohesity cluster services. |
