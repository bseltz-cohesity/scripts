#!/usr/bin/env python
"""Groot Object Run Report"""
from pyhesity import *
import psycopg2
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-q', '--queryfile', type=str, required=True)
parser.add_argument('-o', '--outfile', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
queryfile = args.queryfile
outfile = args.outfile

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt))

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

print('Collecting report data...')

# get groot connection info from cluster
reporting = api('get', 'postgres', quiet=True)
if 'errorCode' in reporting:
    print('statistics DB not found on %s' % vip)
    exit(1)

sql_query = ''
try:
    sqlfile = open(queryfile, 'r')
    sql_query = sqlfile.read()
except Exception:
    print('unable to open sql file')
    exit(1)

# connect to groot
conn = psycopg2.connect(host=reporting[0]['nodeIp'], port=reporting[0]['port'], database="postgres", user=reporting[0]['defaultUsername'], password=reporting[0]['defaultPassword'])
cur = conn.cursor()

cur.execute(sql_query)
rows = cur.fetchall()

f = codecs.open(outfile, 'w', 'utf-8')
colnames = [desc[0] for desc in cur.description]
f.write('%s\n' % '\t'.join(colnames))

for row in rows:
    f.write('%s\n' % '\t'.join([str(i) for i in row]))

cur.close()
print('saving report as %s' % outfile)
f.close()
