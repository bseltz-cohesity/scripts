### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$outpath = '.',
    [Parameter()][string]$nodeIps = $null,
    [Parameter()][string]$services = $null,
    [Parameter()][switch]$listServices,
    [Parameter()][string]$msgTypes = 'INFO,WARNING,ERROR,FATAL',
    [Parameter()][switch]$criticalLogsOnly,
    [Parameter()][switch]$forceDelete,
    [Parameter()][double]$hoursBack = 4,
    [Parameter()][string]$outputDir = '/home/cohesity/data/timecapsules',
    [Parameter()][int]$pollIntervalSecs = 15,
    [Parameter()][int]$pollWaitMins = 30,
    [Parameter()][switch]$dbg
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
# end authentication =========================================

$cluster = api get cluster

# open log file (Out-File -Append opens/writes/closes on each call, so there
# is no file handle to keep open or close explicitly, unlike the Python
# version's codecs.open log file)
$now = Get-Date
$startDateString = $now.ToString('yyyy-MM-dd HH:mm:ss')
$logfile = Join-Path -Path $outpath -ChildPath "timecapsuleLog-$($cluster.name).txt"

"`nScript started at $startDateString ********************************************************" | Out-File -FilePath $logfile -Append
"`nCommand line parameters:`n" | Out-File -FilePath $logfile -Append
$paramNames = @('vip', 'username', 'domain', 'useApiKey', 'password', 'noPrompt', 'mfaCode', 'outpath',
                'nodeIps', 'services', 'listServices', 'msgTypes', 'criticalLogsOnly', 'forceDelete',
                'hoursBack', 'outputDir', 'pollIntervalSecs', 'pollWaitMins', 'dbg')
foreach($p in $paramNames){
    if($p -notin @('password', 'mfaCode', 'noPrompt')){
        "    $($p): $(Get-Variable -Name $p -ValueOnly)" | Out-File -FilePath $logfile -Append
    }
}
"" | Out-File -FilePath $logfile -Append

function out($message, [switch]$quiet){
    if(!$quiet){
        Write-Host $message
    }
    $message | Out-File -FilePath $logfile -Append
}

if($hoursBack -gt 48){
    out "Note: the cluster caps the collection window at 48 hours; the requested $hoursBack hours will be clipped."
}

# time format used by the startTime/endTime fields on the Siren timecapsule form
$TIMEFMT = 'MM/dd/yy HH:mm:ss'

# The startTime/endTime fields on the Siren form are plain "MM/dd/yy
# HH:mm:ss" strings with no timezone info, and Siren interprets them as UTC
# -- not the local timezone of whatever machine this script runs on. Using
# this machine's local time would silently shift the requested window by
# however many hours this machine is offset from UTC, which can make a
# collection miss most of its intended window and come back suspiciously
# small (confirmed against a cluster: the request's own endTimeStr was off
# from the resulting bundle's UTC modTime by exactly this machine's UTC
# offset).
$clusterNow = (Get-Date).ToUniversalTime()

$url = "https://$vip/siren/v1/cluster/timecapsule"

# Siren is legacy tooling that (per Cohesity's own internal docs) validates
# the session-name cookie, not the newer Bearer token/session-id header.
# apiauth's plain username/password /login path should leave a session-name
# cookie in $cohesity_api.session, but an AD/domain login that falls back to
# the accessTokens or v2 session-id path may not -- and Siren may then
# silently render a login/empty page with HTTP 200 instead of erroring,
# which looks exactly like "the script ran fine but nothing shows up in
# Siren."
$sirenCookies = $cohesity_api.session.Cookies.GetCookies($cohesity_api.apiRoot)
if($sirenCookies.Count -eq 0){
    out "Warning: no session cookie was captured from login. If the request below silently does nothing, try authenticating with a local cluster account instead of an AD/domain account, or omit -noPrompt so any password-change/MFA prompts complete normally."
}

# Siren's HTML is inconsistent about quoting attribute values across cluster
# versions (some builds emit value="foo", others emit value=foo with no
# quotes at all), so this matches either form. Only safe for simple,
# space-free values (IPs, service names); label-style checkbox values (see
# scrapeLabelValue below) need their own regex since they contain spaces and
# are always quoted.
function scrapeCheckboxValues($pageText, $fieldName){
    return @([regex]::Matches($pageText, "name=`"$fieldName`"[^>]*?value=`"?([\w.:-]+)`"?") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
}

# Some checkboxes (criticalLogs, forceDeleteTCDir, etc.) submit their
# on-screen label text as the value, e.g. value="Force delete Timecapsule
# dir content", instead of "true" -- sending "true" for those is silently
# ignored by the backend. Pull the real value straight off the live form;
# fall back to a hardcoded guess only if that fails, e.g. if this cluster's
# build doesn't have this checkbox at all.
function scrapeLabelValue($pageText, $fieldName, $fallback){
    $m = [regex]::Match($pageText, "name=`"$fieldName`"[^>]*?value=`"([^`"]*)`"")
    if($m.Success){
        return $m.Groups[1].Value
    }
    return $fallback
}

# Siren's own auth layer can return HTTP 200 with a login page or an empty
# shell instead of erroring out when the session isn't valid for it, which
# otherwise looks just like a normal, successful response.
function checkRealSirenPage($pageText, $label){
    if($pageText -notmatch 'filterForm' -and $pageText -notmatch 'Collect Timecapsule'){
        out "Warning: the $label response did not look like the Siren timecapsule page (no `"Collect Timecapsule`" form found) -- this usually means the session isn't authenticated against Siren, not that the request failed outright. First 300 characters of the response:"
        out $pageText.Substring(0, [Math]::Min(300, $pageText.Length))
        return $false
    }
    return $true
}

# Each row in the "Timecapsule Files" table links directly to the NODE that
# holds the bundle (e.g. https://<nodeIp>/siren/v1/node/timecapsules/<file>),
# not to the cluster vip -- the bundle only exists on the node's local disk,
# and that route isn't proxied through the cluster's main gateway. This
# regex pulls the real, absolute per-node URL straight out of the table row,
# plus its Size column so we can confirm the file has stopped growing before
# downloading it.
$ROWPATTERN = '<td><a href="(https?://[^"]+/siren/v1/node/timecapsules/Timecapsule[-\w.]*\.tar\.gz)"[^>]*>[^<]*</a></td>\s*<td>([^<]+)</td>'

function getRows($pageText){
    $rows = @{}
    foreach($m in [regex]::Matches($pageText, $ROWPATTERN)){
        $rows[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    return $rows
}

$webParams = @{
    'UseBasicParsing' = $true;
    'Headers' = $cohesity_api.header;
    'WebSession' = $cohesity_api.session;
}
if($PSVersionTable.PSEdition -eq 'Core'){
    $webParams['SkipCertificateCheck'] = $true
}

# Snapshot the bundles already listed on the page BEFORE submitting, so the
# poll below can tell a brand new bundle apart from one that was already
# sitting there from a previous run (otherwise a second run of this script
# can match and "download" the old file before the new one even exists).
# This same page load is also used below to pull the CURRENT, version-
# correct set of selectable nodeIps/serviceNames straight from Siren itself,
# rather than trusting a hardcoded list that can go stale the moment a
# cluster is on a different (older or newer) release -- an older build can
# reject the whole request over a single service name it doesn't recognize,
# and Siren accepts that request with an ordinary HTTP 200 (an inline error
# banner, not a failed request), so nothing about the response looks wrong.
$precheck = Invoke-WebRequest @webParams -Uri $url
$null = checkRealSirenPage $precheck.Content 'pre-check'
$existingHrefs = @((getRows $precheck.Content).Keys)
$formNodeIps = scrapeCheckboxValues $precheck.Content 'nodeIps'
$formServiceNames = scrapeCheckboxValues $precheck.Content 'serviceNames'

if($listServices){
    if($formServiceNames){
        out "Service names available for Timecapsule collection on $vip`:"
        foreach($s in ($formServiceNames | Sort-Object)){
            out "  $s"
        }
    }else{
        out "Could not read the service name list from Siren's form on $vip."
    }
    exit 0
}

# resolve node IPs (default: every node Siren's own form lists, i.e. its
# "Select All"; api get nodes is used as a secondary source only to warn if
# it disagrees with what Siren itself considers valid)
if($nodeIps){
    $nodeIpList = @($nodeIps -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}elseif($formNodeIps){
    $nodeIpList = @($formNodeIps | Sort-Object)
}else{
    $nodeIpList = @((api get nodes) | ForEach-Object { $_.ip })
}

if($formNodeIps -and -not ($nodeIpList | Where-Object { $_ -in $formNodeIps })){
    out "Warning: none of the node IPs this script resolved ($($nodeIpList -join ', ')) match the nodeIps checkboxes Siren's own form lists ($($formNodeIps -join ', ')). The request below will likely be accepted and do nothing. Pass -nodeIps with one of the listed IPs explicitly."
}

# resolve service names (default: every service Siren's own form lists for
# THIS cluster/version -- see note above on why a hardcoded list is unsafe)
if($services){
    $serviceList = @($services -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if($formServiceNames){
        $badServices = @($serviceList | Where-Object { $_ -notin $formServiceNames })
        if($badServices.Count -gt 0){
            out "Warning: Siren's form on $vip does not recognize these service names: $($badServices -join ', '). Including them will likely make the whole request get silently rejected. Dropping them."
            $serviceList = @($serviceList | Where-Object { $_ -in $formServiceNames })
        }
    }
}elseif($formServiceNames){
    $serviceList = @($formServiceNames | Sort-Object)
}else{
    out "Warning: could not read the service name list from Siren's form; proceeding with none selected."
    $serviceList = @()
}

$msgTypeList = @($msgTypes -split ',' | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ -ne '' })

$endTime = $clusterNow
$startTime = $clusterNow.AddHours(-1 * $hoursBack)

# build the query string the same way a browser serializes multiple checked
# checkboxes of the same name (repeated key=value pairs)
$queryParts = @()
foreach($ip in $nodeIpList){ $queryParts += "nodeIps=$([uri]::EscapeDataString($ip))" }
foreach($s in $serviceList){ $queryParts += "serviceNames=$([uri]::EscapeDataString($s))" }
foreach($m in $msgTypeList){ $queryParts += "msgType=$([uri]::EscapeDataString($m))" }
$queryParts += "startTime=$([uri]::EscapeDataString($startTime.ToString($TIMEFMT)))"
$queryParts += "endTime=$([uri]::EscapeDataString($endTime.ToString($TIMEFMT)))"
$queryParts += "outputDir=$([uri]::EscapeDataString($outputDir))"

# The form's top/iotop/iostat checkboxes default to checked, and the
# backend defaults their boolean flags to true even if we never send them --
# but it does NOT default their (iterations, interval) args to anything
# sensible when omitted, leaving them blank. top/iotop/iostat running with
# no arguments at all can behave unpredictably and has been observed to cut
# a collection short. Send the same values the form defaults to so this
# always matches a normal browser submission.
$queryParts += 'topLog=true', 'topArgs=1', 'topArgs=30'
$queryParts += 'iotopLog=true', 'iotopArgs=1', 'iotopArgs=30'
$queryParts += 'iostatLog=true', 'iostatArgs=1', 'iostatArgs=30'
if($criticalLogsOnly){
    $val = scrapeLabelValue $precheck.Content 'criticalLogs' 'Collect Critical Logs Only'
    $queryParts += "criticalLogs=$([uri]::EscapeDataString($val))"
}
if($forceDelete){
    $val = scrapeLabelValue $precheck.Content 'forceDeleteTCDir' 'Force delete Timecapsule dir content'
    $queryParts += "forceDeleteTCDir=$([uri]::EscapeDataString($val))"
}

$fullUrl = $url + '?' + ($queryParts -join '&')

out "Requesting Timecapsule collection from $vip"
out "  nodes:    $($nodeIpList -join ', ')"
if($serviceList.Count -lt 6){
    out "  services: $($serviceList -join ', ')"
}else{
    out "  services: $($serviceList.Count) services (all)"
}
out "  window:   $($startTime.ToString($TIMEFMT)) to $($endTime.ToString($TIMEFMT))"
if($dbg){
    out "  full request URL (for manual testing): $fullUrl"
}

$response = Invoke-WebRequest @webParams -Uri $fullUrl
if($dbg){
    out "  response: HTTP $($response.StatusCode), $($response.RawContentLength) bytes"
}
if($response.StatusCode -ne 200){
    out "Timecapsule request failed: HTTP $($response.StatusCode)"
    exit 1
}
$null = checkRealSirenPage $response.Content 'submit'

out "Collection submitted. Waiting for the bundle to appear (up to $pollWaitMins minutes)..."

# Siren's on-prem timecapsule page has no JSON status API -- this polls the
# same rendered "Timecapsule Files" table a person would see refreshing the
# page in a browser, looking for a row that wasn't there before this request
# was submitted, then waits for its Size column to stop changing across two
# consecutive polls (the row can appear before the collection has finished
# writing the file).
$bundleHref = $null
$lastSize = $null
$stable = $false
$deadline = (Get-Date).AddMinutes($pollWaitMins)
while((Get-Date) -lt $deadline){
    $page = Invoke-WebRequest @webParams -Uri $url
    $rows = getRows $page.Content
    $newRows = @{}
    foreach($href in $rows.Keys){
        if($href -notin $existingHrefs){
            $newRows[$href] = $rows[$href]
        }
    }
    if($newRows.Count -gt 0){
        $candidateHref = @($newRows.Keys | Sort-Object)[-1]
        $candidateSize = $newRows[$candidateHref]
        if($candidateHref -eq $bundleHref -and $candidateSize -eq $lastSize){
            $stable = $true
            break
        }
        $bundleHref = $candidateHref
        $lastSize = $candidateSize
    }
    Start-Sleep -Seconds $pollIntervalSecs
}

if(!$bundleHref){
    out "Timed out waiting for a new bundle to appear. Check the Siren UI at $url"
    exit 1
}
if(!$stable){
    out "Warning: gave up waiting for the file size to stabilize; downloading anyway (last seen size: $lastSize)"
}

$bundleName = $bundleHref.Substring($bundleHref.LastIndexOf('/') + 1)
out "Bundle ready: $bundleName ($lastSize)"

$localPath = Join-Path -Path $outpath -ChildPath $bundleName
out "Downloading $bundleHref -> $localPath ..."

# the bundle download link points at the node's own IP, a different host
# than $vip -- the session's cookie jar is scoped by domain, so it won't
# automatically attach to the node's host. copySessionCookie (from
# cohesity-api.ps1) hands that same session-name cookie to the node's IP so
# this already-authenticated session can be reused there too -- the same
# "node context switching" trick gflagList.ps1 uses to reach a node
# directly instead of going through vip.
$bundleNodeIp = ([uri]$bundleHref).Host
copySessionCookie $bundleNodeIp

$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest @webParams -Uri $bundleHref -OutFile $localPath
$ProgressPreference = 'Continue'

out "Done. Bundle saved to $localPath"
Write-Host "Output logged to $logfile`n"
