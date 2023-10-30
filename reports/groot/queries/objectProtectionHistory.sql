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
to_timestamp(reporting.protection_job_run_entities.end_time_usecs / 1000000) BETWEEN (NOW() - INTERVAL '90 days') AND (NOW())
order by to_timestamp(protection_job_run_entities.end_time_usecs  / 1000000) desc