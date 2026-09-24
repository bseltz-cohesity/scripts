#!/usr/bin/env python
"""collect a Timecapsule (support bundle) from a Cohesity cluster via the Siren web UI"""

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime, timedelta, timezone
import os
import codecs
import re
import sys
import time
import urllib3
import requests
import requests.packages.urllib3

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-o', '--outpath', type=str, default='.')
parser.add_argument('-n', '--nodeips', type=str, default=None, help='comma separated node IPs (default: all nodes in the cluster)')
parser.add_argument('-s', '--services', type=str, default=None, help='comma separated service names (default: all services)')
parser.add_argument('-ls', '--listservices', action='store_true', help='print the service names Siren considers valid for this cluster (sorted alphabetically), then exit')
parser.add_argument('-mt', '--msgtypes', type=str, default='INFO,WARNING,ERROR,FATAL', help='comma separated: INFO,WARNING,ERROR,FATAL')
parser.add_argument('-c', '--criticallogsonly', action='store_true')
parser.add_argument('-fd', '--forcedelete', action='store_true', help='force delete the Timecapsule directory\'s existing content on the node(s) before collecting ("Force delete Timecapsule dir content" on the web form)')
parser.add_argument('-hb', '--hoursback', type=float, default=4, help='collect logs from N hours ago until now (cluster caps this at 48 hours)')
parser.add_argument('-od', '--outputdir', type=str, default='/home/cohesity/data/timecapsules', help='directory on the cluster node(s) to write the bundle to')
parser.add_argument('-pi', '--pollintervalsecs', type=int, default=15)
parser.add_argument('-pw', '--pollwaitmins', type=int, default=30, help='minutes to wait for the collection to finish before giving up')
parser.add_argument('-debug', '--debug', action='store_true', help='print the full request URL before submitting it')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
outpath = args.outpath
nodeips = args.nodeips
services = args.services
listservices = args.listservices
msgtypes = args.msgtypes
criticallogsonly = args.criticallogsonly
forcedelete = args.forcedelete
hoursback = args.hoursback
outputdir = args.outputdir
pollintervalsecs = args.pollintervalsecs
pollwaitmins = args.pollwaitmins
debug = args.debug

requests.packages.urllib3.disable_warnings()
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# format used by the startTime/endTime fields on the Siren timecapsule form
TIMEFMT = '%m/%d/%y %H:%M:%S'

# Siren's HTML is inconsistent about quoting attribute values (some builds
# emit value="foo", others emit value=foo with no quotes at all), so this
# matches either form. Only safe for simple, space-free values (IPs,
# service names); label-style checkbox values (see scrapeLabelValue below)
# need their own regex since they contain spaces and are always quoted.
def scrapeCheckboxValues(pageText, fieldName):
    return set(re.findall(r'name="%s"[^>]*?value="?([\w.:-]+)"?' % fieldName, pageText))


def scrapeLabelValue(pageText, fieldName, fallback):
    """Some checkboxes (criticalLogs, forceDeleteTCDir, etc.) submit their
    on-screen label text as the value, e.g. value="Force delete
    Timecapsule dir content", instead of "true" -- sending "true" for
    those is silently ignored by the backend. Pull the real value straight
    off the live form; fall back to a hardcoded guess only if that fails,
    e.g. if this cluster's build doesn't have this checkbox at all."""
    match = re.search(r'name="%s"[^>]*?value="([^"]*)"' % fieldName, pageText)
    return match.group(1) if match else fallback


def out(message, quiet=False):
    if quiet is not True:
        print(message)
    log.write('%s\n' % message)


### authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode)

if apiconnected() is False:
    print('\nFailed to connect to Cohesity cluster')
    exit(1)

print('')

cluster = api('get', 'cluster')

# open log file
now = datetime.now()
startDateString = now.strftime("%Y-%m-%d %H:%M:%S")

logfile = os.path.join(outpath, 'timecapsuleLog-%s.txt' % cluster['name'])
log = codecs.open(logfile, 'a')

log.write('\nScript started at %s ********************************************************\n' % startDateString)
log.write('\nCommand line parameters:\n\n')
for arg, value in vars(args).items():
    if arg not in ['password', 'mfacode', 'noprompt']:
        log.write("    %s: %s\n" % (arg, value))
log.write('\n')

if hoursback > 48:
    out('Note: the cluster caps the collection window at 48 hours; the requested %.1f hours will be clipped.' % hoursback)

# The startTime/endTime fields on the Siren form are plain "MM/DD/YY
# HH:MM:SS" strings with no timezone info, and Siren interprets them as
# UTC -- not the local timezone of whatever machine this script runs on.
# Using datetime.now() (this machine's local time) silently shifts the
# requested window by however many hours this machine is offset from UTC,
# which can make a collection miss most of its intended window and come
# back suspiciously small (confirmed against a cluster: the request's own
# endTimeStr was off from the resulting bundle's UTC modTime by exactly
# this machine's UTC offset).
clusterNow = datetime.now(timezone.utc).replace(tzinfo=None)

context = getContext()
session = context['SESSION']
headers = context['HEADER']
cookies = context.get('COOKIES', {})

# Siren is legacy tooling that (per Cohesity's own internal docs) validates
# the session-name cookie, not the newer Bearer token. pyhesity only
# populates COOKIES when apiauth() takes the plain username/password /login
# path; an AD/domain login that falls back to the accessTokens (Bearer) or
# v2 session-id path leaves COOKIES empty, and Siren may then silently
# render a login/empty page with HTTP 200 instead of erroring -- which
# looks exactly like "the script ran fine but nothing shows up in Siren."
if not cookies:
    out('Warning: no session cookie was captured from login (auth used the token/header path). '
        'If the request below silently does nothing, try authenticating with a local cluster '
        'account instead of an AD/domain account, or re-run with -np omitted so any password- '
        'change/MFA prompts complete normally.')

url = 'https://%s/siren/v1/cluster/timecapsule' % vip

# Each row in the "Timecapsule Files" table links directly to the NODE that
# holds the bundle (e.g. https://<nodeIp>/siren/v1/node/timecapsules/<file>),
# not to the cluster vip -- the bundle only exists on the node's local disk,
# and that route isn't proxied through the cluster's main gateway. Building
# the download URL from vip instead (as an earlier version of this script
# did) hits the wrong backend and silently downloads a small fallback page
# instead of the real archive, which is why the logs looked "missing" --
# the .tar.gz wasn't actually the bundle. This regex pulls the real,
# absolute per-node URL straight out of the table row, plus its Size column
# so we can confirm the file has stopped growing before downloading it.
ROWPATTERN = re.compile(
    r'<td><a href="(https?://[^"]+/siren/v1/node/timecapsules/Timecapsule[-\w.]*\.tar\.gz)"[^>]*>[^<]*</a></td>\s*<td>([^<]+)</td>'
)

def checkRealSirenPage(pageText, label):
    """Sirens's own auth layer can return HTTP 200 with a login page or an
    empty shell instead of erroring out when the session isn't valid for
    it, which otherwise looks just like a normal, successful response."""
    if 'filterForm' not in pageText and 'Collect Timecapsule' not in pageText:
        out('Warning: the %s response did not look like the Siren timecapsule page '
            '(no "Collect Timecapsule" form found) -- this usually means the session '
            'isn\'t authenticated against Siren, not that the request failed outright. '
            'First 300 characters of the response:' % label)
        out(pageText[:300])
        return False
    return True


# Snapshot the bundles already listed on the page BEFORE submitting, so the
# poll below can tell a brand new bundle apart from one that was already
# sitting there from a previous run (otherwise a second run of this script
# can match and "download" the old file before the new one even exists).
# This same page load is also used below to pull the CURRENT, version-
# correct set of selectable nodeIps/serviceNames straight from Siren
# itself, rather than trusting a hardcoded list that can go stale the
# moment a cluster is on a different (older or newer) release -- an older
# build can reject the whole request over a single service name it
# doesn't recognize, and Siren accepts that request with an ordinary
# HTTP 200 (an inline error banner, not a failed request), so nothing
# about the response looks wrong.
precheck = session.get(url, headers=headers, cookies=cookies, verify=False)
checkRealSirenPage(precheck.text, 'pre-check')
existingHrefs = set(href for href, size in ROWPATTERN.findall(precheck.text))
formNodeIps = scrapeCheckboxValues(precheck.text, 'nodeIps')
formServiceNames = scrapeCheckboxValues(precheck.text, 'serviceNames')

if listservices:
    if formServiceNames:
        out('Service names available for Timecapsule collection on %s:' % vip)
        for s in sorted(formServiceNames):
            out('  %s' % s)
    else:
        out('Could not read the service name list from Siren\'s form on %s.' % vip)
    log.close()
    exit(0)

# resolve node IPs (default: every node Siren's own form lists, i.e. its
# "Select All"; api('get', 'nodes') is used as a secondary source only to
# warn if it disagrees with what Siren itself considers valid)
if nodeips is not None:
    nodeIpList = [ip.strip() for ip in nodeips.split(',') if ip.strip() != '']
elif formNodeIps:
    nodeIpList = sorted(formNodeIps)
else:
    nodes = api('get', 'nodes')
    nodeIpList = [node['ip'] for node in nodes]

if formNodeIps and not (set(nodeIpList) & formNodeIps):
    out('Warning: none of the node IPs this script resolved (%s) match the nodeIps checkboxes '
        'Siren\'s own form lists (%s). The request below will likely be accepted and do nothing. '
        'Pass -n with one of the listed IPs explicitly.' % (', '.join(nodeIpList), ', '.join(sorted(formNodeIps))))

# resolve service names (default: every service Siren's own form lists for
# THIS cluster/version -- see note above on why a hardcoded list is unsafe)
if services is not None:
    serviceList = [s.strip() for s in services.split(',') if s.strip() != '']
    if formServiceNames:
        badServices = [s for s in serviceList if s not in formServiceNames]
        if badServices:
            out('Warning: Siren\'s form on %s does not recognize these service names: %s. '
                'Including them will likely make the whole request get silently rejected. '
                'Dropping them.' % (vip, ', '.join(badServices)))
            serviceList = [s for s in serviceList if s in formServiceNames]
elif formServiceNames:
    serviceList = sorted(formServiceNames)
else:
    out('Warning: could not read the service name list from Siren\'s form; proceeding with none selected.')
    serviceList = []

msgTypeList = [m.strip().upper() for m in msgtypes.split(',') if m.strip() != '']

endTime = clusterNow
startTime = clusterNow - timedelta(hours=hoursback)

# requests encodes a list of (key, value) tuples as repeated query params
# (key=a&key=b), the same way the browser serializes multiple checked
# checkboxes on the Siren form.
params = [('nodeIps', ip) for ip in nodeIpList]
params += [('serviceNames', s) for s in serviceList]
params += [('msgType', m) for m in msgTypeList]
params += [
    ('startTime', startTime.strftime(TIMEFMT)),
    ('endTime', endTime.strftime(TIMEFMT)),
    ('outputDir', outputdir)
]
# The form's top/iotop/iostat checkboxes default to checked, and the
# backend defaults their boolean flags to true even if we never send
# them -- but it does NOT default their (iterations, interval) args to
# anything sensible when omitted, leaving them blank. top/iotop/iostat
# running with no arguments at all can behave unpredictably (e.g. top
# expects a terminal without an iteration count) and has been observed
# to cut a collection short. Send the same values the form defaults to
# so this always matches a normal browser submission.
params += [('topLog', 'true'), ('topArgs', '1'), ('topArgs', '30')]
params += [('iotopLog', 'true'), ('iotopArgs', '1'), ('iotopArgs', '30')]
params += [('iostatLog', 'true'), ('iostatArgs', '1'), ('iostatArgs', '30')]
if criticallogsonly:
    params.append(('criticalLogs', scrapeLabelValue(precheck.text, 'criticalLogs', 'Collect Critical Logs Only')))
if forcedelete:
    params.append(('forceDeleteTCDir', scrapeLabelValue(precheck.text, 'forceDeleteTCDir', 'Force delete Timecapsule dir content')))

out('Requesting Timecapsule collection from %s' % vip)
out('  nodes:    %s' % ', '.join(nodeIpList))
out('  services: %s' % (', '.join(serviceList) if len(serviceList) < 6 else '%s services (all)' % len(serviceList)))
out('  window:   %s to %s' % (startTime.strftime(TIMEFMT), endTime.strftime(TIMEFMT)))
if debug:
    prepared = session.prepare_request(requests.Request('GET', url, params=params, headers=headers, cookies=cookies))
    out('  full request URL (for manual testing): %s' % prepared.url)

response = session.get(url, params=params, headers=headers, cookies=cookies, verify=False)
if debug:
    out('  response: HTTP %s, %s bytes' % (response.status_code, len(response.content)))
if response.status_code != 200:
    out('Timecapsule request failed: HTTP %s' % response.status_code)
    log.close()
    exit(1)
checkRealSirenPage(response.text, 'submit')

out('Collection submitted. Waiting for the bundle to appear (up to %s minutes)...' % pollwaitmins)

# Siren's on-prem timecapsule page has no JSON status API -- this polls the
# same rendered "Timecapsule Files" table a person would see refreshing the
# page in a browser, looking for a row that wasn't there before this request
# was submitted, then waits for its Size column to stop changing across two
# consecutive polls (the row can appear before the collection has finished
# writing the file). (If this cluster happens to be CNCE-based, PUT
# /siren/v1/collect + GET /siren/v1/status return real JSON with a task id
# and are worth switching to instead.)
bundleHref = None
lastSize = None
stable = False
deadline = time.time() + (pollwaitmins * 60)
while time.time() < deadline:
    page = session.get(url, headers=headers, cookies=cookies, verify=False)
    newRows = {href: size for href, size in ROWPATTERN.findall(page.text) if href not in existingHrefs}
    if len(newRows) > 0:
        candidateHref = sorted(newRows.keys())[-1]
        candidateSize = newRows[candidateHref]
        if candidateHref == bundleHref and candidateSize == lastSize:
            stable = True
            break
        bundleHref = candidateHref
        lastSize = candidateSize
    time.sleep(pollintervalsecs)

if bundleHref is None:
    out('Timed out waiting for a new bundle to appear. Check the Siren UI at %s' % url)
    log.close()
    exit(1)
if not stable:
    out('Warning: gave up waiting for the file size to stabilize; downloading anyway (last seen size: %s)' % lastSize)

bundleName = bundleHref.rsplit('/', 1)[-1]
out('Bundle ready: %s (%s)' % (bundleName, lastSize))

localPath = os.path.join(outpath, bundleName)
out('Downloading %s -> %s ...' % (bundleHref, localPath))

r = session.get(bundleHref, headers=headers, cookies=cookies, verify=False, stream=True)
if r.status_code != 200:
    out('Download failed: HTTP %s' % r.status_code)
    log.close()
    exit(1)

f = open(localPath, 'wb')
for chunk in r.iter_content(chunk_size=1048576):
    if chunk:
        f.write(chunk)
f.close()

out('Done. Bundle saved to %s' % localPath)
print('Output logged to %s\n' % logfile)
log.close()
