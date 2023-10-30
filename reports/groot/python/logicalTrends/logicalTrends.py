#!/usr/bin/env python
"""Logcal Trends for python"""
from pyhesity import *
import psycopg2
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-n', '--units', type=str, choices=['MB', 'GB', 'TB', 'mb', 'gb', 'tb'], default='GB')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
units = args.units

multiplier = 1024 * 1024 * 1024
if units.lower() == 'mb':
    multiplier = 1024 * 1024
elif units.lower() == 'tb':
    multiplier = 1024 * 1024 * 1024 * 1024

# authenticate
apiauth(vip, username, domain)

print('Collecting report data...')

# get groot connection info from cluster
reporting = api('get', 'postgres', quiet=True)
if 'errorCode' in reporting:
    print('statistics DB not found on %s' % vip)
    exit()

# connect to groot
conn = psycopg2.connect(host=reporting[0]['nodeIp'], port=reporting[0]['port'], database="postgres", user=reporting[0]['defaultUsername'], password=reporting[0]['defaultPassword'])
cur = conn.cursor()

# logical trend sql query
logical_trend = """
select
  start_time_usecs,
  source_logical_size_bytes,
  protection_job_run_entities.entity_id,
  env_name
from
  reporting.protection_job_run_entities
  INNER JOIN reporting.leaf_entities on leaf_entities.entity_id = protection_job_run_entities.entity_id
  INNER JOIN reporting.environment_types on environment_types.env_id = protection_job_run_entities.entity_env_type
WHERE
  start_time_usecs > 0
ORDER BY
  start_time_usecs;"""

# get records
cur.execute(logical_trend)
rows = cur.fetchall()

# data dictionary
trend = {}
trendTypes = []

for row in rows:
    (startTimeUsecs, logicalBytes, entityId, entityType) = row
    startDate = datetime.strptime(usecsToDate(startTimeUsecs), '%Y-%m-%d %H:%M:%S').strftime("%Y-%m-%d")
    if startDate not in trend:
        trend[startDate] = {}
    if entityType not in trend[startDate]:
        trend[startDate][entityType] = {"logicalBytes": 0, "entities": []}
    if entityType not in trendTypes:
        trendTypes.append(entityType)
    if entityId not in trend[startDate][entityType]['entities']:
        trend[startDate][entityType]['logicalBytes'] += logicalBytes
        trend[startDate][entityType]['entities'].append(entityId)

# output to csv
f = open('logicalTrends-%s.csv' % vip, 'w')

# csv header
f.write('%s,%s,,%s,%s\n' % ('Date', ','.join(sorted(trendTypes)), 'Date', ','.join(sorted(trendTypes))))

for startDate in sorted(trend.keys()):
    print(startDate)
    theseLogical = []
    theseCount = []
    for entityType in sorted(trendTypes):
        entityData = trend[startDate].get(entityType, {"logicalBytes": 0, "entities": []})
        logical = round(entityData['logicalBytes'] / multiplier, 2)
        itemCount = len(entityData['entities'])
        print('  %s (%s)  %s' % (entityType, itemCount, logical))
        theseLogical.append(str(logical))
        theseCount.append(str(itemCount))
    f.write('%s,%s,,%s,%s\n' % (startDate, ','.join(theseLogical), startDate, ','.join(theseCount)))
f.close()
