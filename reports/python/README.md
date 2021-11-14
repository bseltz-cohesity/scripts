# Python Reports

Various Python scripts to generate reports

## dataPerObject

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/dataPerObject>

Format: CSV

* Job Name
* Object Name
* Logical Size
* Read Last 24 Hours
* Read Last %s Days
* Written Last 24 Hours
* Written Last %s Days
* Days Gathered

## jobFailures

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/jobFailures>

Format: HTML

## jobRunReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/jobRunReport>

Format: Console

* jobName
* status
* startTime

## licenseReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/licenseReport>

Format: CSV

* featureName
* currentUsageGiB
* numVm

## protectedObjectReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/protectedObjectReport>

Format: CSV

* Cluster Name
* Job Name
* Environment
* Object Name
* Object Type
* Object Size (MiB)
* Parent
* Policy Name
* Policy Link
* Archive Target
* Direct Archive
* Frequency (Minutes)
* Last Backup
* Last Status
* Last Run Type
* Job Paused
* Indexed
* Start Time
* Time Zone
* QoS Policy
* Priority
* Full SLA
* Incremental SLA

## recoveryPoints

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/recoveryPoints>

Format: CSV

* Job Name
* Object Type
* Object Name
* Start Time
* Local Expiry
* Archive Target
* Archive Expiry

## registeredSources

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/registeredSources>

Format: CSV

* Source Name
* Environment
* Protected
* Unprotected
* Auth Status
* Last Refresh
* Error

## storageGrowth

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storageGrowth>

Format: CSV

* Date
* Consumed (GiB)
* Capacity (GiB)
* PCT Full

## storageReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storageReport>

Formats: CSV, HTML

* Job/View Name
* Tenant
* Environment
* Local/Replicated
* Logical
* Ingested
* Consumed
* Written
* Unique
* Dedup Ratio
* Compression
* Reduction

## strikeReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/strikeReport>

Format: HTML

* Object Name
* Type
* Job Name
* Failure Count
* Last Good Backup
* Error Message

## viewFileCounts

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/viewFileCounts>

Format: CSV

* View
* Folders
* Files
