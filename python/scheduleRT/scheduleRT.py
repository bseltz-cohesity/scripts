#!/usr/bin/env python

import sys
import os
from datetime import datetime
import argparse
from pyhesity import *

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-hr', '--hours', type=str, required=True)
parser.add_argument('-s', '--starttime', type=str, required=True)
parser.add_argument('-r', '--repeatdays', type=str, default=0)

args = parser.parse_args()

vip = args.vip                 # cluster name/ip
username = args.username       # username to connect to cluster
domain = args.domain           # domain of username (e.g. local, or AD domain)
hours = args.hours             # num of hours to keep RT open
starttime = args.starttime     # datetime to open rt
repeatdays = args.repeatdays   # number of days to repeat

SCRIPTFOLDER = sys.path[0]
CRONTEMP = os.path.join(SCRIPTFOLDER, 'mycron')
COMMAND = os.path.join(SCRIPTFOLDER, 'enableRT.py')
COMMANDARGS = "-v '%s' -u '%s' -d '%s' -hr '%s' -s '%s' -r '%s'" % (vip, username, domain, hours, starttime, repeatdays)
CRONCMD = "%s %s" % (COMMAND, COMMANDARGS)

# validate credentials
apiauth(vip, username, domain)

# Get current CRONTAB
os.system('crontab -l > %s' % CRONTEMP)

# Calculate cron schedule
dt = datetime.strptime(starttime, '%Y-%m-%d %H:%M:%S')
hour = dt.hour
minute = dt.minute

f = open(CRONTEMP, 'a')
f.write('%s %s * * * %s\n' % (minute, hour, CRONCMD))
f.close()

os.system('crontab %s' % CRONTEMP)
print("Scheduled RT to open at %s" % starttime)
