# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobname
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# get the protectionJob
$jobs = api get -v2 "data-protect/protection-groups?environments=kSQL&names=$jobName"
$job = $jobs.protectionGroups | Where-Object name -eq $jobName
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
}

if($job.mssqlParams.protectionType -ne 'kFile'){
    Write-Host "$jobName is not a file-based SQL job" -ForegroundColor Yellow
    exit
}

# backup old job
$job | ConvertTo-Json -Depth 99 | Out-File -FilePath "$jobName.json"

$newJob = @{
    "name"             = $job.name;
    "policyId"         = $job.policyId;
    "priority"         = $job.priority;
    "storageDomainId"  = $job.storageDomainId;
    "description"      = $job.description;
    "startTime"        = $job.startTime;
    "alertPolicy"      = $job.alertPolicy;
    "sla"              = $job.sla;
    "qosPolicy"        = $job.qosPolicy;
    "abortInBlackouts" = $job.abortInBlackouts;
    "isPaused"         = $job.isPaused;
    "environment"      = "kSQL";
    "permissions"      = @();
    "missingEntities"  = $null;
    "mssqlParams"      = @{
        "protectionType"             = "kVolume";
        "volumeProtectionTypeParams" = @{
            "objects"                       = @($job.mssqlParams.fileProtectionTypeParams.objects);
            "incrementalBackupAfterRestart" = $true;
            "indexingPolicy"                = @{
                "enableIndexing" = $true;
                "includePaths"   = @(
                    "/"
                );
                "excludePaths"   = @(
                    '/$Recycle.Bin';
                    "/Windows";
                    "/Program Files";
                    "/Program Files (x86)";
                    "/ProgramData";
                    "/System Volume Information";
                    "/Users/*/AppData";
                    "/Recovery";
                    "/var";
                    "/usr";
                    "/sys";
                    "/proc";
                    "/lib";
                    "/grub";
                    "/grub2";
                    "/opt/splunk";
                    "/splunk"
                )
            };
            "backupDbVolumesOnly"           = $false;
            "additionalHostParams"          = @();
            "userDbBackupPreferenceType"    = "kBackupAllDatabases";
            "backupSystemDbs"               = $true;
            "useAagPreferencesFromServer"   = $true;
            "fullBackupsCopyOnly"           = $false;
            "excludeFilters"                = $null
        }
    }
}

# delete old job
"Deleting old job..."
$null = api delete -v2 data-protect/protection-groups/$($job.id)

# create new job
"Creating new job..."
$null = api post -v2 data-protect/protection-groups $newJob
