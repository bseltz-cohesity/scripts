#!/usr/bin/env python

from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-i', '--useApiKey', action='store_true')
args = parser.parse_args()

vip = args.vip                  # cluster name/ip
username = args.username        # username to connect to cluster
domain = args.domain            # domain of username (e.g. local, or AD domain)
password = args.password        # password to store
useApiKey = args.useApiKey

if password is not None:
    storePasswordFromInput(vip=vip, username=username, password=password, domain=domain, useApiKey=useApiKey)
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, updatepw=True)
print('password stored')
