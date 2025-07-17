# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory = $True)][string]$objectName,
    [Parameter()][int]$numRuns = 500
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}

$outfileName = "objectRunHistory.csv"

# headings
$headings = "Protection Group
Environment
Run Type
Run Start Time
Local Snapshot Status
Local Snapshot Start Time
Local Snapshot End Time
Local Snapshot Expiry
Archive Status
Archive Start Time
Archive End Time
Archive Expiry"

$headings = $headings -split "`n" -join ""","""
$headings = """$headings"""

$headings | Out-File -FilePath $outfileName -Encoding utf8

$search = api get -v2 "data-protect/search/objects?searchString=$objectName&includeTenants=true&count=100"
$search.objects = $search.objects | Where-Object {$_.name -eq $objectName}

if(!$search.objects -or @($search.objects).Count -eq 0){
    Write-Host "Object $objectName not found" -ForegroundColor Yellow
    exit 1
}

foreach($object in $search.objects){
    if(!$object.objectProtectionInfos.protectionGroups){
        Write-Host "$objectName is not backed up on this cluster" -ForegroundColor Yellow
    }
    foreach($protection in $object.objectProtectionInfos){
        $objectId = $protection.objectId
        # $snaps = api get -v2 "data-protect/objects/$objectId/snapshots"
        foreach($pg in $protection.protectionGroups){
            # Write-Host ($pg | toJson)
            $runs = Get-Runs -jobId $pg.id -includeObjectDetails
            foreach($run in $runs){
                $runStartTimeUsecs = ($run.id -split ":")[1]
                foreach($object in $run.objects){
                    if($object.object.name -eq $objectName){
                        $localStatus = 'N/A'
                        $archiveStatus = 'N/A'
                        $localStatus = ''
                        $localStartTimeUsecs = ''
                        $localEndTimeUsecs = ''
                        $localExpiry = ''
                        $archiveStatus = ''
                        $archiveStartTimeUsecs = ''
                        $archiveEndTimeUsecs = ''
                        $archiveExpiry = ''
                        $runType = ''
                        $includeArchive = $True
                        if($object.PSObject.Properties['localSnapshotInfo']){
                            $localStatus = $object.localSnapshotInfo.snapshotInfo.status
                            if($localStatus -notin @('kSuccessful', 'kWarning')){
                                $includeArchive = $False
                            }
                            $localStartTimeUsecs = (usecsToDate $object.localSnapshotInfo.snapshotInfo.startTimeUsecs).ToString('MM/dd/yyyy HH:mm')
                            $localEndTimeUsecs = (usecsToDate $object.localSnapshotInfo.snapshotInfo.endTimeUsecs).ToString('MM/dd/yyyy HH:mm')
                            $localExpiry = (usecsToDate $object.localSnapshotInfo.snapshotInfo.expiryTimeUsecs).ToString('MM/dd/yyyy HH:mm')
                            $runType = $run.localBackupInfo.runType
                        }
                        if($run.PSObject.Properties['archivalInfo'] -and $includeArchive -eq $True){
                            $archiveStatus = $run.archivalInfo.archivalTargetResults[0].status
                            $archiveStartTimeUsecs = (usecsToDate $run.archivalInfo.archivalTargetResults[0].startTimeUsecs).ToString('MM/dd/yyyy HH:mm')
                            $archiveEndTimeUsecs = (usecsToDate $run.archivalInfo.archivalTargetResults[0].endTimeUsecs).ToString('MM/dd/yyyy HH:mm')
                            $archiveExpiry = (usecsToDate $run.archivalInfo.archivalTargetResults[0].expiryTimeUsecs).ToString('MM/dd/yyyy HH:mm')
                            if($runType -eq ''){
                                $runType = $run.archivalInfo.archivalTargetResults[0].runType
                            }
                        }
                        "{0} [{1}]" -f ($pg.name, (usecsToDate $runStartTimeUsecs).ToString('MM/dd/yyyy HH:mm'))
                        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}"",""{11}""" -f ($pg.name, 
                                                                                                                                $object.object.environment,
                                                                                                                                $runType,
                                                                                                                                (usecsToDate $runStartTimeUsecs).ToString('MM/dd/yyyy HH:mm'),
                                                                                                                                $localStatus,
                                                                                                                                $localStartTimeUsecs,
                                                                                                                                $localEndTimeUsecs,
                                                                                                                                $localExpiry,
                                                                                                                                $archiveStatus,
                                                                                                                                $archiveStartTimeUsecs,
                                                                                                                                $archiveEndTimeUsecs,
                                                                                                                                $archiveExpiry) | Out-File -FilePath $outfileName -Append
                    }
                }
            }  
        }
    }
}
# "Protection Group
# Environment
# Run Type
# Run Start Time
# Local Snapshot Status
# Local Snapshot Start Time
# Local Snapshot End Time
# Local Snapshot Expiry
# Archive Status
# Archive Start Time
# Archive End Time
# Archive Expiry"

"`nOutput saved to $outfilename`n"
