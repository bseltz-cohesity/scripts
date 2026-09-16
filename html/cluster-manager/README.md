# Cluster Manager (HTML)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a web-browser-based Cohesity cluster manager. It combines two tools behind a single login session and a single tabbed UI:

- **Cluster State** — start/stop the cluster, and start/stop/restart individual cluster services.
- **GFlags** — view, set, clear, export/import, and restart services affected by gflag changes.

## Download

You can download the zip file here: <https://raw.githubusercontent.com/cohesity/community-automation-samples/refs/heads/main/html/cluster-manager/cluster-manager.zip>

## Components

- **cluster-manager.html**: the UI. Open this directly in your browser (double-click it, or drag it into a browser tab). No server needed for this part.
- **cluster-manager-proxy.py**: a single local proxy backing both tabs. Cohesity's cluster API doesn't send CORS headers, so a browser can't call it directly from a page hosted anywhere but the cluster itself. This script runs on `127.0.0.1` only, adds the CORS headers the browser requires, and forwards the real requests to your cluster/Helios over HTTPS.
- **cluster-manager-proxy-for-windows.exe**: the same proxy, pre-built for Windows. Use this instead of the `.py` file if the machine doesn't have Python installed.

## Security note

The proxy only binds to `127.0.0.1`, so nothing outside your machine can reach it.

## Running it

1. Start the proxy: either `python3 cluster-manager-proxy.py` or, on Windows without Python, double-click/run `cluster-manager-proxy-for-windows.exe`. (listens on `http://127.0.0.1:8765`).
2. Open `cluster-manager.html` in your browser.
3. Pick an auth mode (username/password, cluster API key, or Helios/MCM with API key + cluster name), fill in the fields, and click Connect.
4. Use the **Cluster State** and **GFlags** tabs to switch between the two feature sets. Connecting once signs in to both.

If the page shows "Local proxy not reachable," the proxy script isn't running.

## Features

### Cluster State tab

- View overall cluster status (running / stopped / syncing)
- Stop or start the entire cluster, with optional progress watching
- View all cluster services and their current state
- Stop, start, or restart selected services, with optional progress watching
- Flags `kNexus` / `kGandalf` as session-risk services before you act on them

### GFlags tab

- View current gflags
- Set or clear a gflag
- Export gflags to a CSV
- Import gflags from a CSV
- Restart services affected by gflag changes this session

## CSV Format for Gflag Imports

Here's an example CSV that can be imported on the GFlags tab:

```text
Service Name,Flag Name,Flag Value,Reason
kIris,iris_read_timeout_msecs_to_magneto,300000,timeouts
kIris,iris_post_timeout_msecs_to_magneto,300000,timeouts
kMagneto,magneto_restore_sql_skip_steps_in_path,true,resume-recovery
kAlerts,alerts_master_suppress_alert_types,60002;;1118;;1043;;1024;;1067;;1033;;10064;;11005,quiet
```

Note: when the flag value contains commas, replace them with ;; as shown in the example above, so that they are parsed correctly by the CSV import.
