#!/usr/bin/env python
"""Add Physical Linux Servers to File-based Protection Job Using Python"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', type=str, default='Ccs')
parser.add_argument('-r', '--region', type=str, default=None)
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-m', '--mailboxname', action='append', type=str)
parser.add_argument('-l', '--mailboxlist', type=str)
parser.add_argument('-p', '--policyname', type=str, required=True)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)
parser.add_argument('-fs', '--fullsla', type=int, default=120)

args = parser.parse_args()

username = args.username              # username to connect to cluster
region = args.region                  # domain of username (e.g. local, or AD domain)
sourcename = args.sourcename
mailboxnames = args.mailboxname       # name of server to protect
mailboxlist = args.mailboxlist        # file with server names
policyname = args.policyname          # policy name for new job
starttime = args.starttime            # start time for new job
timezone = args.timezone              # time zone for new job
incrementalsla = args.incrementalsla  # incremental SLA for new job
fullsla = args.fullsla                # full SLA for new job

# read server file
if mailboxnames is None:
    mailboxnames = []
if mailboxlist is not None:
    f = open(mailboxlist, 'r')
    mailboxnames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

if len(mailboxnames) == 0:
    print('no mailboxes specified')
    exit()

# authenticate to Cohesity
apiauth(username=username, regionid=region)
if apiconnected() is False:
    exit()

# parse starttime
try:
    (hour, minute) = starttime.split(':')
    hour = int(hour)
    minute = int(minute)
    if hour < 0 or hour > 23 or minute < 0 or minute > 59:
        print('starttime is invalid!')
        exit(1)
except Exception:
    print('starttime is invalid!')
    exit(1)

print('')

# find protectionPolicy
policy = [p for p in (api('get', 'data-protect/policies?types=DMaaSPolicy', mcmv2=True)['policies']) if p['name'].lower() == policyname.lower()]
if len(policy) < 1:
    print("Policy '%s' not found!" % policyname)
    exit(1)

# find O365 source
sources = api('get', 'protectionSources?environments=kO365')

source = [s for s in api('get', 'protectionSources?environments=kO365') if s['protectionSource']['name'].lower() == sourcename.lower()]
if source is None or len(source) == 0:
    print('M365 protection source not registered')
    exit()

users = [n for n in source[0]['nodes'] if n['protectionSource']['name'] == 'Users']
if users is None or len(users) == 0:
    print('Protection Source is not configured for O365 Mailboxes')
    exit()

protectionParams = {
    "abortInBlackouts": False,
    "priority": "kMedium",
    "sla": [
        {
            "backupRunType": "kFull",
            "slaMinutes": fullsla
        },
        {
            "backupRunType": "kIncremental",
            "slaMinutes": incrementalsla
        }
    ],
    "startTime": {
        "timeZone": "US/EASTERN",
        "minute": minute,
        "hour": hour
    },
    "objects": [],
    "qosPolicy": "kBackupSSD",
    "policyId": policy[0]['id']
}

mailboxesAdded = 0

for mailbox in mailboxnames:
    user = [u for u in users[0]['nodes'] if u['protectionSource']['name'].lower() == mailbox.lower() or u['protectionSource']['office365ProtectionSource']['primarySMTPAddress'].lower() == mailbox.lower()]
    if user is None or len(user) == 0:
        print('Mailbox %s not found' % mailbox)
    else:
        user = user[0]
        protectionParams['objects'].append({
            "environment": "kO365Exchange",
            "office365Params": {
                "objectProtectionType": "kMailbox",
                "userMailboxObjectProtectionParams": {
                    "indexingPolicy": {
                        "excludePaths": [],
                        "enableIndexing": True,
                        "includePaths": [
                            "/"
                        ]
                    },
                    "objects": [
                        {
                            "id": user['protectionSource']['id']
                        }
                    ]
                }
            }
        })
        print('Protecting %s' % mailbox)
        mailboxesAdded += 1

if mailboxesAdded > 0:
    response = api('post', 'data-protect/protected-objects', protectionParams, v=2)
    print('\nSuccessfully protected:\n')
    for o in response['protectedObjects']:
        print('    %s' % o['name'])
    print('')
else:
    print('No mailboxes protected')
