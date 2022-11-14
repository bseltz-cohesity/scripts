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
parser.add_argument('-c', '--clustername', action='append', type=str)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--minutes', type=int, default=1440)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
minutes = args.minutes

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt))

print('Collecting report data...')

# get groot connection info from cluster
reporting = api('get', 'postgres', quiet=True)
if 'errorCode' in reporting:
    print('statistics DB not found on %s' % vip)
    exit(1)

cluster = api('get', 'cluster')
# limit query to numdays
startUsecs = timeAgo(minutes, 'minutes')

# connect to groot
conn = psycopg2.connect(host=reporting[0]['nodeIp'], port=reporting[0]['port'], database="postgres", user=reporting[0]['defaultUsername'], password=reporting[0]['defaultPassword'])
cur = conn.cursor()

# sql query ----------------------------------------
sql_query = """
select
DISTINCT
    entity_name as "Object Name",
    TRIM (leading 'k' from reporting.environment_types.env_name) as "Source Type",
    reporting.registered_sources.source_name as "Source Name",
    reporting.job_run_status.status_name as "Protection Run Status",
    reporting.protection_job_run_entities.job_id as "Protection Job Id",
    reporting.protection_job_run_entities.job_run_id as "Protection Run Id",
    reporting.protection_jobs.job_name as "Protection Group Name",
    CASE WHEN reporting.protection_job_runs.sla_violated is TRUE then 'Yes' ELSE 'No' END as "SLA Violation",
    to_timestamp(reporting.protection_job_run_entities.start_time_usecs / 1000000) as "Protection Start Time",
    to_timestamp(reporting.protection_job_run_entities.end_time_usecs / 1000000) as "Protection End Time",
    TO_CHAR((TRUNC(reporting.protection_job_run_entities.duration_usecs/6e+7, 2) || ' minute')::interval, 'HH24:MI:SS') as "Protection Duration",
    CASE WHEN reporting.protection_job_run_entities.is_full_backup is True then 'Full Backup' ELSE 'Incremental' END as "Full Backup/Incremental",
    is_Latest_Attempt as "Latest Attempt",
    to_timestamp(reporting.protection_jobs.creation_time_usecs / 1000000) as "Protection Group Creation Time",
    to_timestamp(reporting.protection_jobs.last_modified_time_usecs / 1000000) as "Protection Group Last Modification Time",
    CASE WHEN reporting.protection_jobs.job_status='2' then 'Yes' ELSE 'No' END as "Paused",
    pg_size_pretty(reporting.protection_job_run_entities.source_logical_size_bytes) as "Protection object - Source Logical Size",
    pg_size_pretty(reporting.protection_job_run_entities.source_delta_size_bytes) as "Protection object- Source Delta Size",
    pg_size_pretty(reporting.protection_job_run_entities.data_written_size_bytes) as "Protection object - Data Written Size",
    to_timestamp(reporting.protection_job_runs.snapshot_expiry_time_usecs / 1000000)  as "Local Snapshot Expiry",
    reporting.protection_jobs.policy_id as "Policy Id",
    p1.name as "Policy Name",
    to_timestamp(p1.last_modification_time_usecs / 1000000) as "Policy Last Modification Time",
    p1.num_retries as "Number of Retries",
    reporting.protection_policy_data_lock_type.type_name as "Data Lock",
    CASE WHEN reporting.protection_job_runs.legal_hold is TRUE then 'Yes' ELSE 'No' END as "Legal Hold",
    sp1.name as "Backup Schedule Frequency",
    reporting.backup_schedule.retention_days as "Backup Retention Days",
    reporting.policy_replication_schedule.retention_days as "Replication Retention Days",
    pg_size_pretty(reporting.protection_job_run_replication_entities.logical_size_bytes_transferred) as "Replication -  Logical Size Transferred",
    pg_size_pretty(reporting.protection_job_run_replication_entities.physical_size_bytes_transferred) as "Replication -  Physical Size Transferred",
    reporting.protection_job_runs.error_msg as "Error Message - PG Level",
    reporting.protection_job_run_entities.cluster_id as "Cluster Id",
    reporting.protection_job_run_entities.cluster_incarnation_id as "Cluster Incarnation Id",
    reporting.cluster.cluster_name as "Cluster Name",
    reporting.cluster.software_version as "Cluster Software Version",
    reporting.cluster.timezone as "Cluster Timezone"
from reporting.protection_job_run_entities
    INNER JOIN reporting.protection_jobs on protection_jobs.job_id = protection_job_run_entities.job_id
    INNER JOIN reporting.leaf_entities on leaf_entities.entity_id = protection_job_run_entities.entity_id
    INNER JOIN reporting.environment_types on environment_types.env_id = protection_job_run_entities.entity_env_type
    INNER JOIN reporting.job_run_status on job_run_status.status_id = protection_job_run_entities.status
    INNER JOIN reporting.cluster on reporting.cluster.cluster_id = protection_job_run_entities.cluster_id
    INNER JOIN reporting.protection_policy p1 on p1.id = reporting.protection_jobs.policy_id
    INNER JOIN reporting.protection_job_runs on reporting.protection_job_runs.job_run_id = reporting.protection_job_run_entities.job_run_id
    INNER JOIN reporting.protection_policy_data_lock_type on reporting.protection_policy_data_lock_type.type_id = p1.data_lock
    INNER JOIN reporting.registered_sources on reporting.registered_sources.source_id = reporting.protection_job_run_entities.parent_source_id
    INNER JOIN reporting.backup_schedule on reporting.backup_schedule.policy_id=p1.id
    INNER JOIN reporting.schedule_periodicity sp1 on sp1.id = reporting.backup_schedule.periodicity_id
    LEFT JOIN reporting.policy_replication_schedule on p1.id=policy_replication_schedule.policy_id
    LEFT JOIN reporting.protection_job_run_replication_entities on reporting.protection_job_run_entities.job_run_id = reporting.protection_job_run_replication_entities.job_run_id and reporting.protection_job_run_entities.job_id = reporting.protection_job_run_replication_entities.job_id and reporting.protection_job_run_entities.entity_id=reporting.protection_job_run_replication_entities.entity_id
where
reporting.protection_job_run_entities.end_time_usecs >= %s
order by to_timestamp(protection_job_run_entities.end_time_usecs  / 1000000) desc""" % startUsecs

outfileName = 'objectRuns-%s.csv' % cluster['name']
f = codecs.open(outfileName, 'w', 'utf-8')

cur.execute(sql_query)

colnames = [desc[0] for desc in cur.description]
f.write('%s\n' % ','.join(colnames))

rows = cur.fetchall()
for row in rows:
    f.write('%s\n' % ','.join([str(i) for i in row]))

cur.close()
print('saving report as %s' % outfileName)
f.close()
