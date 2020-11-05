[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][Int64]$jobMultiplier = 3,
    [Parameter(Mandatory = $True)][array]$nasShares,
    [Parameter(Mandatory = $True)][string]$inputFile,
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain',
    [Parameter(Mandatory = $True)][string]$policyName,
    [Parameter()][string]$timeZone = "America/New_York",
    [Parameter()][Int64]$startHour = '20'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get generic nas protection sources
$sources = api get protectionSources?environments=kGenericNas

# get storage domain
$sd = api get viewBoxes | Where-Object name -eq $storageDomain
if(! $sd){
    Write-Host "Storage domain $storageDomain not found!" -ForegroundColor Yellow
    exit 1
}

# get policy
$policy = api get protectionPolicies | Where-Object name -eq $policyName
if(! $policy){
    Write-Host "Policy $policyName not found!" -ForegroundColor Yellow
    exit 1
}

# get input file
$folders = Import-Csv -Path $inputFile
if(! $folders){
    Write-Host "input file $inputFile not found!" -ForegroundColor Yellow
    exit 1
}

# show total object count
$totalRemaining = 0
$folders."Object Count " | ForEach-Object {$totalRemaining += $_}
"`n$totalRemaining to distribute`n"

# job list
$jobs = @()

foreach($nasShare in $nasShares){
    # get protection source ID for nas share
    $nasSource = $sources[0].nodes | Where-Object {$_.protectionSource.name -eq $nasShare}
    if(! $nasSource){
        write-host "NAS $nasShare not found!" -ForegroundColor Yellow
        exit
    }
    # define X jobs per NAS share
    1..$jobMultiplier | ForEach-Object{
        $jobNum = $_
        $thisJob = "$jobName$nasShare-$jobNum".Replace('\','-').Replace('--','-')
        $job = @{
            'name' = $thisJob;
            'nasHead' = $nasShare;
            'objectCount' = 0;
            'jobDefinition' = @{
                "name"                             = $thisJob;
                "environment"                      = "kGenericNas";
                "environmentParameters"            = @{
                    "nasParameters" = @{
                        "nasProtocol"     = "kNfs3";
                        "continueOnError" = $true;
                        "snapshotLabel"   = $null;
                        "filePathFilters" = @{
                            "protectFilters" = @()
                        }
                    }
                }
                "viewBoxId"                        = $sd.id;
                "parentSourceId"                   = $sources[0].protectionSource.id;
                "sourceIds"                        = @($nasSource.protectionSource.id);
                "dedupDisabledSourceIds"           = @();
                "excludeSourceIds"                 = @();
                "vmTagIds"                         = @();
                "excludeVmTagIds"                  = @();
                "policyId"                         = $policy.id;
                "priority"                         = "kMedium";
                "alertingPolicy"                   = @(
                    "kFailure"
                );
                "alertingConfig"                   = @{
                    "emailDeliveryTargets" = @()
                };
                "timezone"                         = $timeZone;
                "incrementalProtectionSlaTimeMins" = 60;
                "fullProtectionSlaTimeMins"        = 120;
                "qosType"                          = "kBackupHDD";
                "isActive"                         = $true;
                "sourceSpecialParameters"          = @();
                "isDeleted"                        = $false;
                "indexingPolicy"                   = @{
                    "disableIndexing" = $true
                };
                "startTime"                        = @{
                    "hour"   = $startHour;
                    "minute" = 00;
                    "second" = 00
                }
            }  
        }
        $jobs += $job
    }
}

foreach($folder in $folders){
    # add folder to job with the least paths
    $folderPath = [string]($folder.FolderPath)
    $folderName = "\{0}\" -f $folderPath.split('\',3)[2]
    $folderName = $folderName.Replace('\','/')
    $objectCount = [Int64]($folder."Object Count ")
    $job = ($jobs | Sort-Object -Property {$_.objectCount} -Descending:$false)[0]
    $job.objectCount = $job.objectCount + $objectCount 
    $job.jobDefinition.environmentParameters.nasParameters.filePathFilters.protectFilters += $folderName
}

foreach($job in $jobs){
    # create the jobs
    $totalDistributed += $job.objectCount
    "Creating job {0} ({1})" -f $job.name, $job.objectCount
    $null = api post protectionJobs $job.jobDefinition
}

# confirmed object count
"`n$totalDistributed distributed`n"
