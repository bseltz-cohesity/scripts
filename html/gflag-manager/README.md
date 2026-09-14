# Gflag Manager (HTML)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a web-browser-based Gflag manager.

## Components

- **gflag-manager.html** — the UI. Open this directly in your browser (double-click it, or drag it into a browser tab). No server needed for this part.
- **gflag-manager-proxy.py** — a tiny local helper. Cohesity's cluster API doesn't send CORS headers, so a browser can't call it directly from a page hosted anywhere but the cluster itself. This script runs on `127.0.0.1` only, adds the CORS headers the browser requires, and forwards the real requests to your cluster/Helios over HTTPS.
- **gflag-manager-proxy-for-windows.exe** — the same proxy, pre-built for Windows. Use this instead of the `.py` file if the machine doesn't have Python installed.

## Security note

The proxy only binds to `127.0.0.1`, so nothing outside your machine can reach it.

## Running it

1. Start the proxy — either `python3 gflag-manager-proxy.py` (standard library only — no `pip install` needed) or, on Windows without Python, double-click/run `gflag-manager-proxy-for-windows.exe`.
2. Open `gflag-manager.html` in your browser.
3. Pick an auth mode (username/password, cluster API key, or Helios/MCM with API key + cluster name), fill in the fields, and click Connect.

If the page shows "Local proxy not reachable," the proxy (py script or .exe) isn't running. On first run, Windows Defender/SmartScreen may flag the `.exe` as unrecognized since it's unsigned — that's a normal false positive, not a sign anything's wrong with it.

## Features

- View current gflags
- Set or clear a gflag
- Export gflags to a CSV
- Inport gflags from a CSV
- Restart affected services

## CSV Format for Imports

Here's an example CSV that can be imported:

```text
Service Name,Flag Name,Flag Value,Reason
kIris,iris_read_timeout_msecs_to_magneto,300000,timeouts
kIris,iris_post_timeout_msecs_to_magneto,300000,timeouts
kMagneto,magneto_restore_sql_skip_steps_in_path,true,resume-recovery
kAlerts,alerts_master_suppress_alert_types,60002;;1118;;1043;;1024;;1067;;1033;;10064;;11005,quiet
```

Note: when the flag value contains commas, replace them with ;; as shown in the example above, so that they are parsed correctly by the CS import.
