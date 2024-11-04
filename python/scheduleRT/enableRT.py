#!/usr/bin/env python
"""Open Support Channel in the Future Using Python"""

### usage: ./enableRT.py -v mycluster -u admin -hr 2 -s '2019-02-28 04:00:00' -r 3

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from datetime import timedelta
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
parser.add_argument('-r', '--repeatdays', type=str, default=0)

args = parser.parse_args()

vip = args.vip                 # cluster name/ip
username = args.username       # username to connect to cluster
domain = args.domain           # domain of username (e.g. local, or AD domain)
hours = args.hours             # num of hours to keep RT open
starttime = args.starttime     # datetime to open rt
repeatdays = int(args.repeatdays)   # number of days to repeat

SCRIPTFOLDER = sys.path[0]
CRONTEMP = os.path.join(SCRIPTFOLDER, 'mycron')
COMMAND = os.path.join(SCRIPTFOLDER, 'enableRT.py')
COMMANDARGS = "-v '%s' -u '%s' -d '%s' -hr '%s' -s '%s' -r '%s'" % (vip, username, domain, hours, starttime, repeatdays)
CRONCMD = "%s %s" % (COMMAND, COMMANDARGS)
os.system('crontab -l > %s' % CRONTEMP)

### wait for start date/time
startdatetime = datetime.strptime(starttime, '%Y-%m-%d %H:%M:%S')
starttime = dateToUsecs(starttime)
endtime = (int(hours) * 60 * 60 * 1000) + (starttime / 1000)
nowdatetime = datetime.now()
repeatdatetime = startdatetime + timedelta(days=repeatdays)
now = dateToUsecs(nowdatetime.strftime("%Y-%m-%d %H:%M:%S"))
repeatuntil = dateToUsecs(repeatdatetime.strftime("%Y-%m-%d %H:%M:%S"))

if (now >= starttime):
    if ((endtime * 1000) > now):
        apiauth(vip, username, domain)
        print("enabling secure channel until %s" % usecsToDate(endtime * 1000))
        rt = {
            "enableReverseTunnel": True,
            "reverseTunnelEnableEndTimeMsecs": endtime
        }
        result = api('put', '/reverseTunnel', rt)

if(now >= repeatuntil):
    # Calculate cron schedule
    hour = startdatetime.hour
    minute = startdatetime.minute

    # clean up crontab
    f = open(CRONTEMP, 'r')
    remove = '%s %s * * * %s\n' % (minute, hour, CRONCMD)
    text = f.readlines()
    f.close()
    f = open(CRONTEMP, 'w')
    for line in text:
        if line != remove:
            f.write(line)
    f.close()
    os.system('crontab %s' % CRONTEMP)
