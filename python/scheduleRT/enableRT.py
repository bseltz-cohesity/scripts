#!/usr/bin/env python
"""Open Support Channel in the Future Using Python"""

### usage: ./enableRT.py -v mycluster -u admin -hr 2 -s '2019-02-28 04:00:00'

### import pyhesity wrapper module
from pyhesity import *
import datetime
import sys
import os

### command line arguments
import argparse
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
os.system('crontab -l > %s' % CRONTEMP)

### wait for start date/time
starttime = dateToUsecs(starttime) - 300000000
endtime = (int(hours) * 60 * 60 * 1000) + (starttime / 1000) + 300000
now = dateToUsecs(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

if (now >= starttime):
    if ((endtime * 1000) > now):
        apiauth(vip, username, domain)
        print "enabling secure channel until %s" % usecsToDate(endtime * 1000)
        rt = {
            "enableReverseTunnel": True,
            "reverseTunnelEnableEndTimeMsecs": endtime
        }
        result = api('put', '/reverseTunnel', rt)

        # clean up crontab
        f = open(CRONTEMP, 'r')
        remove = '*/10 * * * * %s\n' % CRONCMD
        text = f.readlines()
        f.close()
        f = open(CRONTEMP,'w')
        for line in text:
            if line != remove:
                f.write(line)
        f.close()
        os.system('crontab %s' % CRONTEMP)