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
parser.add_argument('-y', '--days', type=int, default=90)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
days = args.days

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

cluster = api('get', 'cluster')

# connect to groot
conn = psycopg2.connect(host=reporting[0]['nodeIp'], port=reporting[0]['port'], database="postgres", user=reporting[0]['defaultUsername'], password=reporting[0]['defaultPassword'])
cur = conn.cursor()

# sql query ----------------------------------------
sql_query = """
select
DISTINCT
    reporting.leaf_entities.entity_name as "Object Name",
    TRIM (leading 'k' from reporting.environment_types.env_name) as "Source Type",
    CASE WHEN parent.entity_name is null then reporting.registered_sources.source_name ELSE parent.entity_name END as "Source Name",
    reporting.job_run_status.status_name as "Object Status",
    reporting.protection_jobs.job_name as "Protection Group Name",
    CASE WHEN reporting.protection_job_runs.sla_violated is TRUE then 'Yes' ELSE 'No' END as "SLA Violation",
    to_timestamp(reporting.protection_job_run_entities.start_time_usecs / 1000000) as "Protection Start Time",
    to_timestamp(reporting.protection_job_run_entities.end_time_usecs / 1000000) as "Protection End Time",
    TO_CHAR((TRUNC(reporting.protection_job_run_entities.duration_usecs/6e+7, 2) || ' minute')::interval, 'HH24:MI:SS') as "Protection Duration",
    to_timestamp(reporting.protection_job_runs.snapshot_expiry_time_usecs / 1000000)  as "Local Snapshot Expiry",
    reporting.backup_schedule.retention_days as "Backup Retention Days",
    reporting.protection_job_runs.error_msg as "Error Message - PG Level"
from reporting.protection_job_run_entities
    INNER JOIN reporting.registered_sources on reporting.registered_sources.source_id = reporting.protection_job_run_entities.parent_source_id
    INNER JOIN reporting.protection_jobs on protection_jobs.job_id = protection_job_run_entities.job_id
    INNER JOIN reporting.leaf_entities on leaf_entities.entity_id = protection_job_run_entities.entity_id
    LEFT JOIN reporting.leaf_entities as parent on leaf_entities.parent_id = parent.entity_id
    INNER JOIN reporting.environment_types on environment_types.env_id = protection_job_run_entities.entity_env_type
    INNER JOIN reporting.job_run_status on job_run_status.status_id = protection_job_run_entities.status
    INNER JOIN reporting.protection_policy p1 on p1.id = reporting.protection_jobs.policy_id
    INNER JOIN reporting.protection_job_runs on reporting.protection_job_runs.job_run_id = reporting.protection_job_run_entities.job_run_id
    INNER JOIN reporting.backup_schedule on reporting.backup_schedule.policy_id=p1.id
    INNER JOIN reporting.schedule_periodicity sp1 on sp1.id = reporting.backup_schedule.periodicity_id
    LEFT JOIN reporting.policy_replication_schedule on p1.id=policy_replication_schedule.policy_id
    LEFT JOIN reporting.protection_job_run_replication_entities on reporting.protection_job_run_entities.job_run_id = reporting.protection_job_run_replication_entities.job_run_id and reporting.protection_job_run_entities.job_id = reporting.protection_job_run_replication_entities.job_id and reporting.protection_job_run_entities.entity_id=reporting.protection_job_run_replication_entities.entity_id
where
to_timestamp(reporting.protection_job_run_entities.end_time_usecs / 1000000) BETWEEN (NOW() - INTERVAL '%s days') AND (NOW())
order by to_timestamp(protection_job_run_entities.end_time_usecs  / 1000000) desc""" % days

cur.execute(sql_query)
rows = cur.fetchall()

latestJobRunId = 0
if len(rows) > 0:
    latestJobRunId = rows[0][5]

outfileName = 'protectionAuditReport-%s.tsv' % cluster['name']
f = codecs.open(outfileName, 'w', 'utf-8')
colnames = [desc[0] for desc in cur.description]
f.write('%s\n' % '\t'.join(colnames))

for row in rows:
    f.write('%s\n' % '\t'.join([str(i) for i in row]))

cur.close()
print('saving report as %s' % outfileName)
f.close()
