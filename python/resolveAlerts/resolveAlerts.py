#!/usr/bin/env python
"""Resolve alerts using Python"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-s', '--severity', type=str, default=None)
parser.add_argument('-t', '--alerttype', type=str, default=None)
parser.add_argument('-r', '--resolution', type=str, default=None)

args = parser.parse_args()

vip = args.vip            # cluster name/ip
username = args.username  # username to connect to cluster
domain = args.domain      # domain of username (e.g. local, or AD domain)
severity = args.severity
alerttype = args.alerttype
resolution = args.resolution

### authenticate
apiauth(vip, username, domain)

alerts = api('get', 'alerts')

alerts = [a for a in alerts if a['alertState'] != 'kResolved']

if severity is not None:
    alerts = [a for a in alerts if a['severity'].lower() == severity.lower()]

if alerttype is not None:
    alerts = [a for a in alerts if a['alertType'] == alerttype]

alertIds = [a['id'] for a in alerts]

for alert in alerts:
    print('%s\t%s\t%s' % (alert['alertType'], alert['severity'], alert['alertDocument']['alertDescription']))

if resolution is not None:
    alertResolution = {
        "alertIdList": alertIds,
        "resolutionDetails": {
            "resolutionDetails": resolution,
            "resolutionSummary": resolution
        }
    }
    result = api('post', 'alertResolutions', alertResolution)
