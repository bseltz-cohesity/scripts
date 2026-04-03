#!/usr/bin/env python

from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey

envname = 'COH_%s_%s_%s_%s' % (vip, domain, username, str(useApiKey))
envname = envname.replace('.','_').replace('-','_').upper()
print('you can store your secret in environment variable: COH_SECRET or %s' % envname)
