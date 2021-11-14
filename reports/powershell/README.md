# PowerShell Reports

Various PowerShell scripts to generate reports

## archivedObjects

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/archivedObjects>

Format: CSV

* Job Name
* Job Type
* Protected Object
* Latest Backup Date
* Latest Archive Date
* Archive Target

## backedUpFSReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/backedUpFSReport>

Formats: CSV, HTML

* Job Name
* Job Type
* Protected Object
* Latest Backup Date
* Path

## backupSummaryReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/backupSummaryReport>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/chargebackReport>

Formats: CSV, HTML

* Object
* Size (GB)
* Cost

## cloneList

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/cloneList>

Format: CSV

* TaskId
* Created
* Type
* Source
* Target

## cloudArchiveDirectStats

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/cloudArchiveDirectStats>

Format: CSV

* Job Name
* Object Name
* Run Date
* Logical Size
* Logical Transferred
* Phyisical Transferred
* External Target

## dailyObjectStatus

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/dailyObjectStatus>

Format: CSV

* Job Name
* Job Type
* Object Name
* Status
* Last Run
* Duration (Seconds)
* Message

## datalockJobList

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/datalockJobList>

Formats: CSV, HTML

* Job Name
* Environment
* Policy
* Data Lock
* Storage Domain
* Encrypted

## dataPerObject

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/dataPerObject>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/externalTargetStorageStats>

Format: CSV

* Date
* Archived GiB
* Used GiB
* Garbage Collected GiB

## frontEndCapacityReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/frontEndCapacityReport>

Format: CSV

* Job Name
* Location
* Tenant
* Object Name
* Object Type
* Logical Size
* Unique Size

## heatMapReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/heatMapReport>

Format: HTML

* Parent
* Object
* Type
* Status last 7 days

## jobFailures

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/jobFailures>

Format: HTML

## jobList

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/jobList>

Formats: CSV, HTML

* Job Name
* Environment
* Local/Replicated
* Policy
* Storage Domain
* Encrypted
* Start Time

## jobObjects

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/jobObjects>

Format: CSV

* Job Name
* Job Type
* Policy Name
* Object Name

## jobRecoveryPoints

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/jobRecoveryPoints>

Format: CSV

* Job Name
* Job Type
* Backup Date
* Local Expiry
* Archival Target
* Archival Expiry

## jobRunDuration

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/jobRunDuration>

Format: CSV

* JobName
* StartTime
* Duration (Seconds)
* MB Read

## jobRunStats

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/jobRunStats>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/lastRunObjectStats>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/legalHoldRunList>

Format: CSV

* Job Name
* RunDate

## licenseReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/licenseReport>

Format: CSV

* featureName
* currentUsageGiB
* numVm

## nasObjectStats

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/nasObjectStats>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/objectHistoryReport>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/objectRunStats>

Format: CSV

* Date
* Day of Week
* Duration in Minutes
* Date Read GiB
* Data Written GiB
* Files Backed Up
* Total Files

## objectStatusReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/objectStatusReport>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/objectSummaryReport>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/protectedFilePathReport>

Formats: CSV, HTML

* Job Name
* Server Name
* Path
* Include/Exclude

## protectedObjectReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/protectedObjectReport>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/protectionReport>

Format: HTML

## recoveryPoints

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/recoveryPoints>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/redundantProtectionReport>

Format: CSV

* Object
* Type
* Protection Jobs

## registeredSources

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/registeredSources>

Format: CSV

* Source Name
* Environment
* Protected
* Unprotected
* Auth Status
* Last Refresh
* Error

## restoreFilesReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/restoreFilesReport>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/restoreReport>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/runningJobs>

Format: CSV

* JobName
* StartTime
* TargetType
* Status

## sizingReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/sizingReport>

Format: CSV

* Owner
* Job Name
* Job Type
* Source Name
* Logical
* Peak Read
* Last Day Read
* Read Over Days
* Last Day Written
* Written Over Days
* Days Collected
* Daily Read Change Rate %
* Daily Write Change Rate %

## slaStatus

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/slaStatus>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/sqlProtectedObjectReport>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/storageGrowth>

Format: CSV

* Cluster
* Date
* Consumed (GiB)
* Capacity (GiB)
* PCT Full

## storageReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/storageReport>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/strikeReport>

Format: HTML

* Object Name
* DB Name
* Object Type
* Job Name
* Failure Count
* Last Good Backup
* Last Error

## summaryReportXLSX

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/summaryReportXLSX>

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

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/viewFileCounts>

Format: CSV

* View
* Folders
* Files

## vmProtectionReport

<https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/vmProtectionReport>

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
