#!/usr/bin/env python
"""Store Password for python"""

# usage: ./storePassword.py -v mycluster -u myuser -d mydomain.net

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain

storepw(vip, username, domain)
