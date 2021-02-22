#!/usr/bin/env python
"""Groot Object Report"""
from pyhesity import *
import psycopg2
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-n', '--numdays', type=int, default=31)
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB'], default='MiB')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
numdays = args.numdays
units = args.units

multiplier = 1024 * 1024 * 1024  # GiB
if units == 'MiB':
    multiplier = 1024 * 1024

# authenticate
apiauth(vip, username, domain)

print('Collecting report data...')

# get groot connection info from cluster
reporting = api('get', 'postgres', quiet=True)
if 'errorCode' in reporting:
    print('statistics DB not found on %s' % vip)
    exit()

cluster = api('get', 'cluster')
# limit query to numdays
startUsecs = timeAgo(numdays, 'days')

# connect to groot
conn = psycopg2.connect(host=reporting[0]['nodeIp'], port=reporting[0]['port'], database="postgres", user=reporting[0]['defaultUsername'], password=reporting[0]['defaultPassword'])
cur = conn.cursor()

# sql query ----------------------------------------
sql_query = """
select
  pj.job_name as "Job Name",
  le.entity_name AS "Object Name",
  jre.source_delta_size_bytes as "Data Read",
  jre.data_written_size_bytes as "Data Written"
from
  reporting.protection_job_run_entities jre,
  reporting.protection_jobs pj,
  reporting.leaf_entities le,
  reporting.environment_types et,
  reporting.protection_job_runs pjr,
  reporting.protection_policy ppolicy
where
  jre.is_latest_attempt = true
  and jre.job_id = pj.job_id
  and jre.entity_id = le.entity_id
  and jre.entity_env_type = et.env_id
  and jre.job_run_id = pjr.job_run_id
  and et.env_name = 'kVMware'
  and pj.policy_id = ppolicy.id
  and jre.start_time_usecs > %s
order by
  to_timestamp(jre.start_time_usecs / 1000000) desc;""" % startUsecs

now = datetime.now()
date = now.strftime("%m/%d/%Y %H:%M:%S")

csv = 'Job Name,Object Name,Data Read (%s),Data Written (%s)\n' % (units, units)

totals = {}

# get failures
cur.execute(sql_query)
rows = cur.fetchall()
for row in rows:
    (jobName, objectName, dataread, dataWritten) = row
    mykey = '%s-%s' % (jobName, objectName)
    if mykey not in totals:
        totals[mykey] = {
            "jobName": jobName,
            "objectName": objectName,
            "read": 0,
            "written": 0
        }
    totals[mykey]['read'] += dataread
    totals[mykey]['written'] += dataWritten

cur.close()
conn.close()

for mykey in sorted(totals):
    jobName = totals[mykey]['jobName']
    objectName = totals[mykey]['objectName']
    dataRead = round(totals[mykey]['read'] / multiplier, 2)
    dataWritten = round(totals[mykey]['written'] / multiplier, 2)
    csv += '%s,%s,%s,%s\n' % (jobName, objectName, dataRead, dataWritten)

outfileName = 'dataPerVM-%s.csv' % cluster['name']

print('saving report as %s' % outfileName)
f = codecs.open(outfileName, 'w', 'utf-8')
f.write(csv)
f.close()
