#!/usr/bin/env python
"""Tear Down instant volume mount"""

# usage: ./instantVolumeMountDestroy.py -v mycluster \
#                                       -u myuser \
#                                       -d mydomain.net \
#                                       -t 104106

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-t', '--taskid', type=int, required=True)   # job name

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
taskid = args.taskid

# authenticate
apiauth(vip, username, domain)

tearDownTask = api('post', '/destroyclone/%s' % taskid)
print('Tearing down mount points...')
