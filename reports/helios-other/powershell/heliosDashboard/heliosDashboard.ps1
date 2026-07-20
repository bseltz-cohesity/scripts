# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
#  heliosDashboard.ps1
#  Builds an HTML health/status dashboard for all clusters connected to Helios
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password = $null,
    [Parameter()][ValidateSet('GiB', 'TiB')][string]$unit = 'TiB',
    [Parameter()][ValidateSet('Light', 'Dark')][string]$theme = 'Dark',
    [Parameter()][int]$alertDays = 7,
    [Parameter()][string]$outfileName = $null,
    [Parameter()][switch]$show
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to Helios
apiauth -vip $vip -username $username -domain $domain -password $password -helios

if (-not $cohesity_api.authorized) {
    Write-Host "Unable to authenticate to $vip" -ForegroundColor Yellow
    exit 1
}

$dateString = (Get-Date).ToString('yyyy-MM-dd_HHmm')
if (-not $outfileName) {
    $outfileName = "heliosDashboard-$dateString.html"
}

$conversion = @{'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024 }

function Format-Bytes($val) {
    if ($null -eq $val -or $val -eq 0) { return '0 ' + $unit }
    return "{0:n1} {1}" -f ($val / $conversion[$unit]), $unit
}

function Format-Age($usecs) {
    if (-not $usecs) { return 'n/a' }
    $dt = usecsToDate $usecs
    $span = (Get-Date) - $dt
    if ($span.TotalDays -ge 1) { return "{0:N0}d ago" -f $span.TotalDays }
    elseif ($span.TotalHours -ge 1) { return "{0:N0}h ago" -f $span.TotalHours }
    elseif ($span.TotalMinutes -ge 1) { return "{0:N0}m ago" -f $span.TotalMinutes }
    else { return 'just now' }
}

function Format-Timestamp($usecs) {
    if (-not $usecs) { return 'n/a' }
    return usecsToDate $usecs 'yyyy-MM-dd HH:mm'
}

function HtmlEncode($text) {
    if ($null -eq $text) { return '' }
    return [System.Net.WebUtility]::HtmlEncode("$text")
}

function Get-HealthBadge($cluster) {
    if ($cluster.isConnectedToHelios -ne $true) {
        return '<span class="badge badge-muted">Disconnected</span>'
    }
    switch ($cluster.health) {
        'NonCritical' { return '<span class="badge badge-ok">Healthy</span>' }
        'Critical' { return '<span class="badge badge-critical">Critical</span>' }
        default { return '<span class="badge badge-muted">Unknown</span>' }
    }
}

function Get-StatusBadge($status) {
    switch ($status) {
        'UpToDate' { return '<span class="badge badge-ok">Up To Date</span>' }
        'UpgradeAvailable' { return '<span class="badge badge-info">Upgrade Available</span>' }
        'InProgress' { return '<span class="badge badge-info">Upgrading</span>' }
        'Scheduled' { return '<span class="badge badge-info">Scheduled</span>' }
        'Failed' { return '<span class="badge badge-critical">Upgrade Failed</span>' }
        'ClusterUnreachable' { return '<span class="badge badge-muted">Unreachable</span>' }
        default { return '<span class="badge badge-muted">n/a</span>' }
    }
}

function Get-SeverityBadge($severity) {
    switch ($severity) {
        'kCritical' { return '<span class="badge badge-critical">Critical</span>' }
        'kWarning' { return '<span class="badge badge-warning">Warning</span>' }
        'kInfo' { return '<span class="badge badge-info">Info</span>' }
        default { return '<span class="badge badge-muted">n/a</span>' }
    }
}

function Get-RunStatusBadge($status) {
    switch ($status) {
        'Succeeded' { return '<span class="badge badge-ok">Succeeded</span>' }
        'SucceededWithWarning' { return '<span class="badge badge-warning">Succeeded w/ Warning</span>' }
        'Failed' { return '<span class="badge badge-critical">Failed</span>' }
        'Running' { return '<span class="badge badge-info">Running</span>' }
        'Accepted' { return '<span class="badge badge-info">Accepted</span>' }
        'Finalizing' { return '<span class="badge badge-info">Finalizing</span>' }
        'Canceling' { return '<span class="badge badge-muted">Canceling</span>' }
        'Canceled' { return '<span class="badge badge-muted">Canceled</span>' }
        'Skipped' { return '<span class="badge badge-muted">Skipped</span>' }
        'Missed' { return '<span class="badge badge-muted">Missed</span>' }
        'OnHold' { return '<span class="badge badge-muted">On Hold</span>' }
        'LegalHold' { return '<span class="badge badge-muted">Legal Hold</span>' }
        'Paused' { return '<span class="badge badge-muted">Paused</span>' }
        default { return '<span class="badge badge-muted">n/a</span>' }
    }
}

function Get-PausedBadge($isPaused) {
    if ($isPaused -eq $true) { return '<span class="badge badge-warning">Paused</span>' }
    return '<span class="no-data">&ndash;</span>'
}

function Get-PieColor($pct) {
    if ($pct -ge 90) { return '#e74c3c' }
    elseif ($pct -ge 70) { return '#f39c12' }
    else { return '#2ecc71' }
}

function Get-PieHtml($pct) {
    $color = Get-PieColor $pct
    $pctDisplay = [math]::Round($pct, 0)
    $gradient = "conic-gradient($color 0% $pct%, #e2e8f0 $pct% 100%)"
    return "<div class=`"pie-wrap`"><div class=`"pie`" style=`"background: $gradient`"></div><div class=`"pie-hole`">$pctDisplay%</div></div>"
}

function Get-AlertCountHtml($critCount, $warnCount) {
    $critClass = if ($critCount -gt 0) { 'crit' } else { 'zero' }
    $warnClass = if ($warnCount -gt 0) { 'warn' } else { 'zero' }
    return "<span class=`"$critClass`">$critCount critical</span><span class=`"$warnClass`">$warnCount warning</span>"
}

# returns the most relevant run-summary object (local/replication/archival) for a
# protection group's last run, so we have one place to pull status/time/messages from
function Get-LastRunSummary($pg) {
    $lastRun = $pg.lastRun
    if (-not $lastRun) { return $null }
    if ($lastRun.localBackupInfo) { return $lastRun.localBackupInfo }
    if ($lastRun.originalBackupInfo) { return $lastRun.originalBackupInfo }
    if ($lastRun.archivalInfo) { return $lastRun.archivalInfo.archivalTargetResults[0] }
    return $null
}

$showProtectionGroups = $True

"`nGathering cluster and alert data from $vip...`n"

# time window for alert queries
$endUsecs = [int64] (dateToUsecs (Get-Date))
$startUsecs = [int64] (timeAgo $alertDays days)

# 1) cluster list, status, and health -----------------------------------------------------------
$clusterInfoResp = api get -mcmv2 "cluster-mgmt/info"
$clusters = @($clusterInfoResp.cohesityClusters) | Where-Object { $null -ne $_ } | Sort-Object clusterName

if (@($clusters).Count -eq 0) {
    Write-Host "No clusters returned from cluster-mgmt/info" -ForegroundColor Yellow
}

# 2) open critical/warning alerts, used for the Active Alerts counts, the latest alert per
#    cluster, and the detail table below -----------------------------------------------------
# note: queried per-cluster (via clusterIdentifiers) rather than one global call. The global
# /mcm/alerts call appears to hard-cap its response around 1000 alerts regardless of the
# maxAlerts value requested, which can silently truncate results in a busy environment and make
# alerts from some clusters vanish entirely. Querying per cluster keeps each response well under
# that cap. Each alert is also tagged with the cluster identity from this loop (rather than
# trusting the clusterId/clusterName fields on the alert itself), which sidesteps any possible
# ID-format mismatch between this endpoint and cluster-mgmt/info.
# note: the API's startDateUsecs/endDateUsecs filter on when an alert was first raised, not on
# when it was last seen. A recurring alert first raised well before the window, but still
# actively occurring (deduped) within it, would be dropped entirely by that filter even though
# it's genuinely active right now - showing up nowhere and with zero counts. So instead we pull
# all open alerts per cluster and filter client-side on latestTimestampUsecs (most recent
# occurrence), which is what "active within the alert window" actually means. Counts are derived
# from this same list so the Active Alerts column always matches the latest alert column and the
# detail table.
$rawAlerts = @()
foreach ($cluster in $clusters) {
    if ($cluster.isConnectedToHelios -ne $true) {
        # skip disconnected clusters - there's nothing current to fetch, and it saves a call
        continue
    }
    $clusterIdentifier = if ($cluster.clusterIncarnationId) { "$($cluster.clusterId):$($cluster.clusterIncarnationId)" } else { "$($cluster.clusterId)" }
    $clusterAlertsResp = api get -mcmv2 "alerts?alertStateList=kOpen&alertSeverityList=kCritical,kWarning&clusterIdentifiers=$clusterIdentifier&maxAlerts=1000"
    $clusterRawAlerts = @($clusterAlertsResp.alertsList) | Where-Object { $null -ne $_ }
    foreach ($a in $clusterRawAlerts) {
        $a | Add-Member -NotePropertyName 'ResolvedClusterId' -NotePropertyValue "$($cluster.clusterId)" -Force
        $a | Add-Member -NotePropertyName 'ResolvedClusterName' -NotePropertyValue $cluster.clusterName -Force
        $rawAlerts += $a
    }
}

$openAlerts = @($rawAlerts) | Where-Object {
    $_.latestTimestampUsecs -and
    $_.latestTimestampUsecs -ge $startUsecs -and $_.latestTimestampUsecs -le $endUsecs
}

$statsByClusterMap = @{}
foreach ($a in $openAlerts) {
    $cid = $a.ResolvedClusterId
    if (-not $statsByClusterMap.ContainsKey($cid)) {
        $statsByClusterMap[$cid] = @{ numCriticalAlerts = 0; numWarningAlerts = 0 }
    }
    if ($a.severity -eq 'kCritical') { $statsByClusterMap[$cid].numCriticalAlerts++ }
    elseif ($a.severity -eq 'kWarning') { $statsByClusterMap[$cid].numWarningAlerts++ }
}

# "latest alert" per cluster prefers critical alerts over warnings - if a cluster has any open
# critical alert, its most recent critical alert is shown here even if a warning came in more
# recently. Only when a cluster has no open critical alerts does its most recent warning show.
$latestAlertMap = @{}
foreach ($grp in ($openAlerts | Group-Object ResolvedClusterId)) {
    $criticalAlerts = @($grp.Group | Where-Object { $_.severity -eq 'kCritical' })
    $candidates = if (@($criticalAlerts).Count -gt 0) { $criticalAlerts } else { $grp.Group }
    $latestAlertMap[$grp.Name] = $candidates | Sort-Object latestTimestampUsecs -Descending | Select-Object -First 1
}

# group alerts by cluster, cap at 3 per cluster, clusters listed alphabetically. Critical alerts
# fill the 3 slots first (newest first); only if criticals don't fill all 3 slots do the newest
# warnings fill the remainder.
$sortedAlertDetails = @()
$alertsByCluster = $openAlerts | Group-Object ResolvedClusterName | Sort-Object Name
$zebraIndex = 0
foreach ($grp in $alertsByCluster) {
    $criticalRows = @($grp.Group | Where-Object { $_.severity -eq 'kCritical' } | Sort-Object latestTimestampUsecs -Descending | Select-Object -First 3)
    $remainingSlots = 3 - @($criticalRows).Count
    $warningRows = if ($remainingSlots -gt 0) { @($grp.Group | Where-Object { $_.severity -eq 'kWarning' } | Sort-Object latestTimestampUsecs -Descending | Select-Object -First $remainingSlots) } else { @() }
    $groupRows = @($criticalRows) + @($warningRows)
    $thisZebraIndex = $zebraIndex
    $sortedAlertDetails += @($groupRows | Select-Object *, @{Name = 'ZebraGroup'; Expression = { $thisZebraIndex } })
    $zebraIndex++
}

# 3) protection groups per cluster, used for the optional Protection Groups table -----------------
# only fetched when -showProtectionGroups is passed, since it's an extra round of calls that isn't
# needed for the core dashboard. The Helios-wide /mcm/data-protect/protection-groups endpoint
# doesn't return correct/complete data, so instead this queries each cluster's own v2 API
# (/v2/data-protect/protection-groups) individually. heliosCluster switches the API session's
# access-cluster context so calls route through Helios to that specific cluster; it's reset back
# to the Helios-wide context (heliosCluster '-') once all clusters have been queried.
# includeLastRunInfo=true pulls back each group's most recent run (status, start time, and any
# error/warning messages) in the same call. Paginated via paginationCookie in case a cluster has
# more Protection Groups than fit in a single page.
$sortedProtectionGroups = @()
if ($showProtectionGroups) {
    "Gathering protection group data from $vip...`n"

    $pgByCluster = @{}
    foreach ($cluster in $clusters) {
        if ($cluster.isConnectedToHelios -ne $true) {
            # skip disconnected clusters - there's nothing current to fetch
            continue
        }
        $null = heliosCluster $cluster.clusterName

        $clusterProtectionGroups = @()
        $paginationCookie = $null
        do {
            $uri = "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&includeLastRunInfo=true"
            if ($paginationCookie) { $uri += "&paginationCookie=$paginationCookie" }
            $pgResp = api get -v2 $uri
            $clusterProtectionGroups += @($pgResp.protectionGroups) | Where-Object { $null -ne $_ }
            $paginationCookie = $pgResp.paginationCookie
        } while ($paginationCookie)

        if (@($clusterProtectionGroups).Count -gt 0) {
            foreach ($pg in $clusterProtectionGroups) {
                $pg | Add-Member -NotePropertyName 'ResolvedClusterName' -NotePropertyValue $cluster.clusterName -Force
            }
            $pgByCluster[$cluster.clusterName] = $clusterProtectionGroups
        }
    }
    # return the API session to the Helios-wide context
    $null = heliosCluster '-'

    # group by cluster (alphabetically), groups within a cluster sorted by name, zebra striped
    # per cluster like the alert detail table above
    $pgZebraIndex = 0
    foreach ($clusterName in ($pgByCluster.Keys | Sort-Object)) {
        $groupRows = $pgByCluster[$clusterName] | Sort-Object name
        $thisZebraIndex = $pgZebraIndex
        $sortedProtectionGroups += @($groupRows | Select-Object *, @{Name = 'ZebraGroup'; Expression = { $thisZebraIndex } })
        $pgZebraIndex++
    }
}

# 4) build summary counters ----------------------------------------------------------------------
$totalClusters = @($clusters).Count
$connectedClusters = @($clusters | Where-Object { $_.isConnectedToHelios -eq $true }).Count
$disconnectedClusters = $totalClusters - $connectedClusters
$criticalHealthClusters = @($clusters | Where-Object { $_.health -eq 'Critical' }).Count
$totalCriticalAlerts = @($openAlerts | Where-Object { $_.severity -eq 'kCritical' }).Count
$totalWarningAlerts = @($openAlerts | Where-Object { $_.severity -eq 'kWarning' }).Count

"`nFound $totalClusters clusters ($connectedClusters connected, $disconnectedClusters disconnected)"
"$totalCriticalAlerts active critical alerts, $totalWarningAlerts active warning alerts (last $alertDays days)`n"
if ($showProtectionGroups) {
    "$(@($sortedProtectionGroups).Count) protection groups found across all clusters`n"
}

# 5) build the HTML ------------------------------------------------------------------------------
$sb = [System.Text.StringBuilder]::new()

[void]$sb.Append(@'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Helios Cluster Health Dashboard</title>
<style>
  :root {
    --ok: #3fa66a;
    --warning: #f39c12;
    --critical: #e74c3c;
    --info: #4a80b0;
    --muted: #95a5a6;
    --bg: #f4f6f8;
    --card-bg: #ffffff;
    --panel: #fafbfc;
    --border: #e2e8f0;
    --text: #2c3e50;
    --subtext: #7f8c8d;
    --zebra: #eef2f5;
  }
  body.dark {
    --bg: #10151b;
    --card-bg: #1b232c;
    --panel: #212b36;
    --border: #2c3846;
    --text: #e6edf3;
    --subtext: #9fb0bd;
    --zebra: #202a35;
  }
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    margin: 0;
    padding: 24px;
  }
  .container { max-width: 1320px; margin: 0 auto; }
  h1 { margin: 0 0 4px 0; font-size: 24px; }
  h2.section-title { margin: 32px 0 12px 0; font-size: 16px; color: var(--text); }
  .subtitle { color: var(--subtext); margin-bottom: 24px; font-size: 13px; }
  .cards {
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
    margin-bottom: 28px;
  }
  .card {
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 16px 20px;
    min-width: 150px;
    flex: 1;
    box-shadow: 0 1px 2px rgba(0,0,0,0.08);
  }
  .card .value { font-size: 26px; font-weight: 700; }
  .card .label { font-size: 12px; color: var(--subtext); text-transform: uppercase; letter-spacing: 0.04em; margin-top: 4px; }
  .card.ok .value { color: var(--ok); }
  .card.warning .value { color: var(--warning); }
  .card.critical .value { color: var(--critical); }
  .card.muted .value { color: var(--muted); }
  table.dashboard-table {
    width: 100%;
    border-collapse: collapse;
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 10px;
    overflow: hidden;
    box-shadow: 0 1px 2px rgba(0,0,0,0.08);
  }
  table.dashboard-table th {
    text-align: left;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--subtext);
    background: var(--panel);
    padding: 10px 14px;
    border-bottom: 1px solid var(--border);
  }
  table.dashboard-table td {
    padding: 10px 14px;
    border-bottom: 1px solid var(--border);
    font-size: 13px;
    vertical-align: middle;
  }
  table.dashboard-table tr:last-child td { border-bottom: none; }
  table.dashboard-table tr:hover td { background: var(--panel); }
  table.dashboard-table tr.zebra-b td { background: var(--zebra); }
  table.dashboard-table.alerts-table tr:hover td { background: var(--card-bg); }
  table.dashboard-table.alerts-table tr.zebra-b:hover td { background: var(--zebra); }
  table.alert-detail-table th, table.alert-detail-table td { padding: 6px 10px; }
  .date-cell { white-space: nowrap; }
  .cluster-name { font-weight: 600; text-transform: uppercase; }
  .badge {
    display: inline-block;
    padding: 3px 9px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 600;
    color: #fff;
    white-space: nowrap;
  }
  .badge-ok { background: var(--ok); }
  .badge-warning { background: var(--warning); }
  .badge-critical { background: var(--critical); }
  .badge-info { background: var(--info); }
  .badge-muted { background: var(--muted); }
  .pie-wrap { position: relative; width: 48px; height: 48px; flex: none; }
  .pie { width: 48px; height: 48px; border-radius: 50%; }
  .pie-hole {
    position: absolute;
    top: 6px; left: 6px;
    width: 36px; height: 36px;
    border-radius: 50%;
    background: var(--card-bg);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    font-weight: 700;
  }
  .capacity-cell { display: flex; align-items: center; gap: 10px; }
  .capacity-text { font-size: 11px; color: var(--subtext); }
  .alert-counts { min-width: 84px; }
  .alert-counts span { display: block; font-size: 12px; line-height: 1.5; white-space: nowrap; }
  .alert-counts .crit { color: var(--critical); font-weight: 700; }
  .alert-counts .warn { color: var(--warning); font-weight: 700; }
  .alert-counts .zero { color: var(--subtext); font-weight: 400; }
  .latest-alert-name { font-weight: 600; }
  .latest-alert-age { font-size: 11px; color: var(--subtext); display: block; }
  .no-alert, .no-data { color: var(--subtext); font-size: 12px; }
  .alert-summary { max-width: 320px; }
  .alert-summary .desc { font-size: 12px; color: var(--subtext); display: block; margin-top: 2px; }
  footer { margin-top: 20px; font-size: 11px; color: var(--subtext); }
</style>
</head>
'@)

$bodyClass = if ($theme -eq 'Dark') { ' class="dark"' } else { '' }
[void]$sb.Append("<body$bodyClass>")
[void]$sb.Append('<div class="container">')

[void]$sb.Append("<h1>Helios Cluster Health Dashboard</h1>")
[void]$sb.Append("<div class=`"subtitle`">Source: $(HtmlEncode $vip) &nbsp;|&nbsp; Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') &nbsp;|&nbsp; Active alert stats window: last $alertDays day(s)</div>")

# summary cards
[void]$sb.Append('<div class="cards">')
[void]$sb.Append("<div class=`"card`"><div class=`"value`">$totalClusters</div><div class=`"label`">Total Clusters</div></div>")
[void]$sb.Append("<div class=`"card ok`"><div class=`"value`">$connectedClusters</div><div class=`"label`">Connected</div></div>")
[void]$sb.Append("<div class=`"card muted`"><div class=`"value`">$disconnectedClusters</div><div class=`"label`">Disconnected</div></div>")
[void]$sb.Append("<div class=`"card critical`"><div class=`"value`">$criticalHealthClusters</div><div class=`"label`">Clusters w/ Critical Health</div></div>")
[void]$sb.Append("<div class=`"card critical`"><div class=`"value`">$totalCriticalAlerts</div><div class=`"label`">Active Critical Alerts</div></div>")
[void]$sb.Append("<div class=`"card warning`"><div class=`"value`">$totalWarningAlerts</div><div class=`"label`">Active Warning Alerts</div></div>")
[void]$sb.Append('</div>')

# cluster table
[void]$sb.Append(@'
<table class="dashboard-table">
<thead>
<tr>
  <th>Cluster</th>
  <th>Health</th>
  <th>Version</th>
  <th>Latest Patch</th>
  <th>Upgrade Status</th>
  <th>Nodes</th>
  <th>Capacity</th>
  <th>Active Alerts</th>
  <th>Latest Alert</th>
</tr>
</thead>
<tbody>
'@)

foreach ($cluster in $clusters) {
    $cid = "$($cluster.clusterId)"
    $name = HtmlEncode $cluster.clusterName
    $isDisconnected = ($cluster.isConnectedToHelios -ne $true)
    $versionShort = if ($cluster.currentVersion) { ($cluster.currentVersion -split '_release')[0] } else { $null }
    $version = if ($isDisconnected -or -not $versionShort) { '&ndash;' } else { HtmlEncode $versionShort }
    $patch = if ($isDisconnected -or -not $cluster.currentPatchVersion) { '&ndash;' } else { HtmlEncode $cluster.currentPatchVersion }
    $upgradeStatusHtml = if ($isDisconnected) { '&ndash;' } else { Get-StatusBadge $cluster.status }
    $nodes = if ($isDisconnected -or $null -eq $cluster.numberOfNodes) { '&ndash;' } else { $cluster.numberOfNodes }

    $total = $cluster.totalCapacity
    $used = $cluster.usedCapacity
    $pct = 0
    if ($total -and $total -gt 0) {
        $pct = [math]::Round((100 * $used / $total), 1)
    }
    $capacityText = "$(Format-Bytes $used) / $(Format-Bytes $total)"
    $hasCapacityData = ($total -and $total -gt 0)
    $capacityCellHtml = if ($isDisconnected -or -not $hasCapacityData) { '<span class="no-data">&ndash;</span>' } else { "$(Get-PieHtml $pct)<span class=`"capacity-text`">$capacityText</span>" }

    $clusterAlertStats = $statsByClusterMap[$cid]
    $critCount = 0
    $warnCount = 0
    if ($clusterAlertStats) {
        if ($clusterAlertStats.numCriticalAlerts) { $critCount = $clusterAlertStats.numCriticalAlerts }
        if ($clusterAlertStats.numWarningAlerts) { $warnCount = $clusterAlertStats.numWarningAlerts }
    }
    $alertCountsHtml = if ($isDisconnected) { '<span class="no-data">&ndash;</span>' } else { Get-AlertCountHtml $critCount $warnCount }

    $latestAlert = $latestAlertMap[$cid]
    if ($isDisconnected) {
        $latestAlertHtml = '<span class="no-alert">Cluster disconnected from Helios</span>'
    }
    elseif ($latestAlert) {
        $alertName = HtmlEncode $latestAlert.alertDocument.alertName
        if (-not $alertName) { $alertName = HtmlEncode $latestAlert.alertCategory }
        $alertAge = Format-Age $latestAlert.latestTimestampUsecs
        $latestAlertHtml = "$(Get-SeverityBadge $latestAlert.severity)<br/><span class=`"latest-alert-name`">$alertName</span><span class=`"latest-alert-age`">$alertAge</span>"
    }
    else {
        $latestAlertHtml = '<span class="no-alert">No open critical/warning alerts</span>'
    }

    [void]$sb.Append('<tr>')
    [void]$sb.Append("<td class=`"cluster-name`">$name</td>")
    [void]$sb.Append("<td>$(Get-HealthBadge $cluster)</td>")
    [void]$sb.Append("<td>$version</td>")
    [void]$sb.Append("<td>$patch</td>")
    [void]$sb.Append("<td>$upgradeStatusHtml</td>")
    [void]$sb.Append("<td>$nodes</td>")
    [void]$sb.Append("<td><div class=`"capacity-cell`">$capacityCellHtml</div></td>")
    [void]$sb.Append("<td><div class=`"alert-counts`">$alertCountsHtml</div></td>")
    [void]$sb.Append("<td>$latestAlertHtml</td>")
    [void]$sb.Append('</tr>')
}

[void]$sb.Append('</tbody></table>')

# optional protection groups table ----------------------------------------------------------------
if ($showProtectionGroups) {
    [void]$sb.Append("<h2 class=`"section-title`">Protection Groups ($(@($sortedProtectionGroups).Count) total, grouped by cluster)</h2>")
    [void]$sb.Append(@'
<table class="dashboard-table alerts-table">
<thead>
<tr>
  <th>Cluster</th>
  <th>Protection Group</th>
  <th>Last Run</th>
  <th>Last Status</th>
  <th>Paused</th>
  <th>Errors / Warnings</th>
</tr>
</thead>
<tbody>
'@)

    if (@($sortedProtectionGroups).Count -eq 0) {
        [void]$sb.Append('<tr><td colspan="6"><span class="no-data">No protection groups found.</span></td></tr>')
    }
    else {
        foreach ($pg in $sortedProtectionGroups) {
            $pgClusterName = HtmlEncode $pg.ResolvedClusterName
            $pgName = HtmlEncode $pg.name

            $runSummary = Get-LastRunSummary $pg
            $lastRunHtml = if ($runSummary -and $runSummary.startTimeUsecs) { HtmlEncode (Format-Timestamp $runSummary.startTimeUsecs) } else { '<span class="no-data">&ndash;</span>' }
            $lastStatusHtml = if ($runSummary -and $runSummary.status) { Get-RunStatusBadge $runSummary.status } else { '<span class="badge badge-muted">n/a</span>' }
            $pausedHtml = Get-PausedBadge $pg.isPaused

            $messages = @()
            if ($runSummary -and $runSummary.messages) { $messages = @($runSummary.messages) | Where-Object { $_ } }
            $issuesHtml = if (@($messages).Count -gt 0) { "<span class=`"desc`">$(HtmlEncode ($messages -join '; '))</span>" } else { '<span class="no-data">&ndash;</span>' }

            $zebraClass = if (($pg.ZebraGroup % 2) -eq 0) { 'zebra-a' } else { 'zebra-b' }

            [void]$sb.Append("<tr class=`"$zebraClass`">")
            [void]$sb.Append("<td class=`"cluster-name`">$pgClusterName</td>")
            [void]$sb.Append("<td>$pgName</td>")
            [void]$sb.Append("<td>$lastRunHtml</td>")
            [void]$sb.Append("<td>$lastStatusHtml</td>")
            [void]$sb.Append("<td>$pausedHtml</td>")
            [void]$sb.Append("<td class=`"alert-summary`">$issuesHtml</td>")
            [void]$sb.Append('</tr>')
        }
    }

    [void]$sb.Append('</tbody></table>')
}

# alert detail table
[void]$sb.Append("<h2 class=`"section-title`">Open Critical &amp; Warning Alerts ($(@($sortedAlertDetails).Count) shown, up to 3 per cluster)</h2>")
[void]$sb.Append(@'
<table class="dashboard-table alerts-table alert-detail-table">
<thead>
<tr>
  <th>Cluster</th>
  <th>Severity</th>
  <th>Category</th>
  <th>Alert</th>
  <th>Description</th>
  <th class="date-cell">First Seen</th>
  <th class="date-cell">Last Seen</th>
  <th>Occurrences</th>
</tr>
</thead>
<tbody>
'@)

if (@($sortedAlertDetails).Count -eq 0) {
    [void]$sb.Append('<tr><td colspan="8"><span class="no-data">No open critical or warning alerts in the selected window.</span></td></tr>')
}
else {
    foreach ($a in $sortedAlertDetails) {
        $alertClusterName = HtmlEncode $a.ResolvedClusterName
        $category = HtmlEncode $a.alertCategory
        $alertName = HtmlEncode $a.alertDocument.alertName
        if (-not $alertName) { $alertName = HtmlEncode $a.alertCode }
        $alertSummary = HtmlEncode $a.alertDocument.alertSummary
        $alertDescriptionHtml = if ($a.alertDocument.alertDescription) { HtmlEncode $a.alertDocument.alertDescription } else { '<span class="no-data">&ndash;</span>' }
        $firstSeen = Format-Timestamp $a.firstTimestampUsecs
        $lastSeen = Format-Timestamp $a.latestTimestampUsecs
        $occurrences = if ($a.dedupCount -and $a.dedupCount -gt 0) { $a.dedupCount } else { 1 }

        $alertCell = "<span class=`"latest-alert-name`">$alertName</span>"
        if ($alertSummary) {
            $alertCell = "$alertCell<span class=`"desc`">$alertSummary</span>"
        }

        $zebraClass = if (($a.ZebraGroup % 2) -eq 0) { 'zebra-a' } else { 'zebra-b' }

        [void]$sb.Append("<tr class=`"$zebraClass`">")
        [void]$sb.Append("<td class=`"cluster-name`">$alertClusterName</td>")
        [void]$sb.Append("<td>$(Get-SeverityBadge $a.severity)</td>")
        [void]$sb.Append("<td>$category</td>")
        [void]$sb.Append("<td class=`"alert-summary`">$alertCell</td>")
        [void]$sb.Append("<td class=`"alert-summary`">$alertDescriptionHtml</td>")
        [void]$sb.Append("<td class=`"date-cell`">$firstSeen</td>")
        [void]$sb.Append("<td class=`"date-cell`">$lastSeen</td>")
        [void]$sb.Append("<td>$occurrences</td>")
        [void]$sb.Append('</tr>')
    }
}

[void]$sb.Append('</tbody></table>')

[void]$sb.Append("<footer>heliosDashboard.ps1 &mdash; generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</footer>")
[void]$sb.Append('</div></body></html>')

$sb.ToString() | Out-File -FilePath $outfileName -Encoding utf8

"`nDashboard saved to $outfileName`n"

if ($show) {
    if ($PSVersionTable.Platform -eq 'Unix') {
        if ($IsMacOS) { Start-Process $outfileName } else { xdg-open $outfileName }
    }
    else {
        Invoke-Item $outfileName
    }
}
