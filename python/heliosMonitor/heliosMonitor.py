#!/usr/bin/env python
"""aag failover / sql log chain monitor"""

from pyhesity import *
from time import sleep

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='admin')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-s', '--sleeptime', type=int, default=30)
parser.add_argument('-t', '--timeout', type=int, default=3600)
args = parser.parse_args()

vip = args.vip
username = args.username
password = args.password
noprompt = args.noprompt
sleeptime = args.sleeptime
timeout = args.timeout

now = dateToUsecs()

while apiconnected() is False:
    try:
        apiauth(vip=vip, username=username, password=password, helios=True, prompt=(not noprompt), quiet=True)
    except Exception:
        pass
    elapsed = dateToUsecs() - now
    if elapsed > (timeout * 1000000):
        print('\nTimed out waiting for Helios to start\n')
        exit(1)
    if apiconnected() is False:
        sleep(sleeptime)
    else:
        print('\nHelios is operational\n')
