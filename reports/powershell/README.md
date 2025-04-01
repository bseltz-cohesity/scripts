# PowerShell Reports

Various PowerShell scripts to generate reports

## archivedObjects

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/archivedObjects>

Format: CSV

* Job Name
* Job Type
* Protected Object
* Latest Backup Date
* Latest Archive Date
* Archive Target

## backedUpFSReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/backedUpFSReport>

Formats: CSV, HTML

* Job Name
* Job Type
* Protected Object
* Latest Backup Date
* Path

## backupSummaryReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/backupSummaryReport>

Format: CSV

* Protection Group
* Type
* Source
* Successful Runs
* Failed Runs
* Last Run Successful Objects
* Last Run Failed Objects
* Data Read Total
* Data Written Total
* SLA Violation
* Last Run Status
* Last Run Date
* Last Run Copy Status

## chargebackReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/chargebackReport>

Formats: CSV, HTML

* Object
* Size (GB)
* Cost

## cloneList

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/cloneList>

Format: CSV

* TaskId
* Created
* Type
* Source
* Target

## cloudArchiveDirectStats

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/cloudArchiveDirectStats>

Format: CSV

* Job Name
* Object Name
* Run Date
* Logical Size
* Logical Transferred
* Phyisical Transferred
* External Target

## dailyObjectStatus

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/dailyObjectStatus>

Format: CSV

* Job Name
* Job Type
* Object Name
* Status
* Last Run
* Duration (Seconds)
* Message

## datalockJobList

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/datalockJobList>

Formats: CSV, HTML

* Job Name
* Environment
* Policy
* Data Lock
* Storage Domain
* Encrypted

## dataPerObject

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/dataPerObject>

Format: CSV

* Job Name
* Environment
* Object Name
* Logical Size
* Read Last 24 Hours
* Read Last X Days
* Written Last 24 Hours
* Written Last X Days
* Days Gathered

## externalTargetStorageStats

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/externalTargetStorageStats>

Format: CSV

* Date
* Archived GiB
* Used GiB
* Garbage Collected GiB

## heatMapReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/heatMapReport>

Format: HTML

* Parent
* Object
* Type
* Status last 7 days

## jobFailures

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/jobFailures>

Format: HTML

## jobList

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/jobList>

Formats: CSV, HTML

* Job Name
* Environment
* Local/Replicated
* Policy
* Storage Domain
* Encrypted
* Start Time

## jobObjects

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/jobObjects>

Format: CSV

* Job Name
* Job Type
* Policy Name
* Object Name

## jobRecoveryPoints

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/jobRecoveryPoints>

Format: CSV

* Job Name
* Job Type
* Backup Date
* Local Expiry
* Archival Target
* Archival Expiry

## jobRunDuration

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/jobRunDuration>

Format: CSV

* JobName
* StartTime
* Duration (Seconds)
* MB Read

## jobRunStats

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/jobRunStats>

Format: CSV

* JobName
* JobType
* Status
* RunDate
* RunType
* DurationSec
* LogicalMB
* DataReadMB
* DataWrittenMB
* RunURL

## lastRunObjectStats

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/lastRunObjectStats>

Format: CSV

* Job Name
* Environment
* Origination
* Policy Name
* Object Name
* Last Run
* Status
* Logical Size
* Data Read
* Data Written
* Data Replicated

## legalHoldRunList

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/legalHoldRunList>

Format: CSV

* Job Name
* RunDate

## licenseReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/licenseReport>

Format: CSV

* featureName
* currentUsageGiB
* numVm

## nasObjectStats

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/nasObjectStats>

Format: CSV

* JobName
* Object
* Date
* Duration in Minutes
* Date Read GiB
* Data Written GiB
* Files Backed Up
* Total Files

## objectHistoryReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/objectHistoryReport>

Format: HTML

* Protection Object Type
* Protection Object Name
* Registered Source Name
* Protection Job Name
* Num Snapshots
* Last Run Status
* Schedule Type
* Last Run Start Time
* End Time
* First Successful Snapshot
* First Failed Snapshot
* Last Successful Snapshot
* Last Failed Snapshot
* Num Errors
* Data Read
* Logical Protected
* Last Error Message

## objectRunStats

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/objectRunStats>

Format: CSV

* Date
* Day of Week
* Duration in Minutes
* Date Read GiB
* Data Written GiB
* Files Backed Up
* Total Files

## objectStatusReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/objectStatusReport>

Format: CSV

* Protection Object Type
* Protection Object Name
* Registered Source Name
* Protection Job Name
* Num Snapshots
* Last Run Status
* Schedule Type
* Last Run Start Time
* End Time
* First Successful Snapshot
* First Failed Snapshot
* Latest Successful Snapshot
* Latest Failed Snapshot
* Num Errors
* Data Read
* Logical Protected
* Organization Names

## objectSummaryReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/objectSummaryReport>

Format: HTML

* Object Type
* Object Name
* Database
* Registered Source
* Job Name
* Available Snapshots
* Latest Status
* Schedule Type
* Last Start Time
* Last End Time
* Logical MB
* Read MB
* Written MB
* File Count
* Change %
* Failure Count
* Error Message

## protectedFilePathReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectedFilePathReport>

Formats: CSV, HTML

* Job Name
* Server Name
* Path
* Include/Exclude

## protectedObjectReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectedObjectReport>

Format: CSV

* Cluster Name
* Job Name
* Environment
* Object Name
* Object Type
* Parent
* Policy Name
* Frequency (Minutes)
* Last Backup
* Last Status
* Job Paused

## protectionReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectionReport>

Format: HTML

## recoveryPoints

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/recoveryPoints>

Format: CSV

* Job Name
* Job Type
* Protected Object
* Recovery Date
* Local Expiry
* Archival Expiry
* Archive Target
* Run URL

## redundantProtectionReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/redundantProtectionReport>

Format: CSV

* Object
* Type
* Protection Jobs

## registeredSources

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/registeredSources>

Format: CSV

* Source Name
* Environment
* Protected
* Unprotected
* Auth Status
* Last Refresh
* Error

## restoreFilesReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/restoreFilesReport>

Formats: CSV, HTML

* Date
* Task
* Source
* Target
* Target Path
* File/Folder
* Source Path
* Status
* Duration (Min)
* User

## restoreReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/restoreReport>

Formats: CSV, HTML

* Date
* Task
* Object
* Type
* Target
* Status
* Duration (Min)
* User

## runningJobs

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/runningJobs>

Format: CSV

* JobName
* StartTime
* TargetType
* Status

## slaStatus

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/slaStatus>

Format: CSV

* Job Name
* Last Run
* Run Type
* Status
* Run Minutes
* SLA Minutes
* SLA Status
* Replication Minutes

## sqlProtectedObjectReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/sqlProtectedObjectReport>

Format: CSV

* Cluster Name
* Job Name
* Environment
* Object Name
* Object Type
* Parent
* Policy Name
* Frequency (Minutes)
* Run Type
* Status
* Start Time
* End Time
* Duration (Minutes)
* Expires
* Job Paused

## storageGrowth

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storageGrowth>

Format: CSV

* Cluster
* Date
* Consumed (GiB)
* Capacity (GiB)
* PCT Full

## storageReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storageReport>

Format: CSV, HTML

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

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/strikeReport>

Format: HTML

* Object Name
* DB Name
* Object Type
* Job Name
* Failure Count
* Last Good Backup
* Last Error

## summaryReportXLSX

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/summaryReportXLSX>

Format: XLSX

* Protection Object Type
* Protection Object Name
* Registered Source Name
* Protection Job Name
* Num Snapshots
* Last Run Status
* Schedule Type
* Last Run Start Time
* End Time
* First Successful Snapshot
* First Failed Snapshot
* Last Successful Snapshot
* Last Failed Snapshot
* Num Errors
* Data Read
* Logical Protected
* Last Error Message

## viewFileCounts

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/viewFileCounts>

Format: CSV

* View
* Folders
* Files

## vmProtectionReport

<https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/vmProtectionReport>

Format: CSV

* vmId
* vmName
* vmSizeBytes
* vmSize
* registeredSourceId
* registeredSourceName
* datacenterName
* hostName
* protected
* indexed
