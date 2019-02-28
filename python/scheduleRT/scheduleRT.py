#!/usr/bin/env python

import sys
import os
import argparse
from pyhesity import *

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-hr', '--hours', type=str, required=True)
parser.add_argument('-s', '--starttime', type=str, required=True)

args = parser.parse_args()

vip = args.vip                 # cluster name/ip
username = args.username       # username to connect to cluster
domain = args.domain           # domain of username (e.g. local, or AD domain)
hours = args.hours             # num of hours to keep RT open
starttime = args.starttime     # datetime to open rt

SCRIPTFOLDER = sys.path[0]
CRONTEMP = os.path.join(SCRIPTFOLDER, 'mycron')
COMMAND = os.path.join(SCRIPTFOLDER, 'enableRT.py')
COMMANDARGS = "-v '%s' -u '%s' -d '%s' -hr '%s' -s '%s'" % (vip, username, domain, hours, starttime)
CRONCMD = "%s %s" % (COMMAND, COMMANDARGS)

# validate credentials
apiauth(vip,username,domain)

# Get current CRONTAB
os.system('crontab -l > %s' % CRONTEMP)

f = open(CRONTEMP, 'a')
f.write('*/10 * * * * %s\n' % CRONCMD)
f.close()

os.system('crontab %s' % CRONTEMP)
print "Scheduled RT to open at %s" % starttime
