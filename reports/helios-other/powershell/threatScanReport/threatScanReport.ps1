[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][int]$days = 7,
    [Parameter()][string]$scanName,
    [Parameter()][string]$objectName,
    [Parameter()][string]$threatFamily,
    [Parameter()][string]$startDate = '',
    [Parameter()][string]$endDate = '',
    [Parameter()][array]$clusterNames,
    [Parameter()][ValidateSet('critical', 'high', 'medium', 'low')][string[]]$severity,
    [Parameter()][switch]$includeSuppressed,
    [Parameter()][int]$pageSize = 100
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain 'local' -helios

### build a lookup of cluster names by clusterId:clusterIncarnationId
$connectedClusters = @(heliosClusters)
$clusterLookup = @{}
foreach($cluster in $connectedClusters){
    $clusterLookup["$($cluster.clusterId):$($cluster.clusterIncarnationId)"] = $cluster.name
    # fallback key (clusterId only) in case incarnation id is not returned
    if(!$clusterLookup.ContainsKey("$($cluster.clusterId)")){
        $clusterLookup["$($cluster.clusterId)"] = $cluster.name
    }
}

function getClusterName($objectId){
    $idParts = @($objectId -split ':')
    if($idParts.Count -ge 2){
        $name = $clusterLookup["$($idParts[0]):$($idParts[1])"]
        if(!$name){
            $name = $clusterLookup["$($idParts[0])"]
        }
        if($name){
            return $name
        }
    }
    return "$($idParts[0]):$($idParts[1])"
}

if($clusterNames){
    $validClusterNames = @($connectedClusters.name)
    $invalidClusterNames = @($clusterNames) | Where-Object {$_ -notin $validClusterNames}
    if($invalidClusterNames){
        Write-Host "Invalid cluster name(s) specified: $($invalidClusterNames -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

### determine start and end dates
$today = Get-Date
$uStart = timeAgo $days 'days'
$uEnd = dateToUsecs ($today)
if($startDate -ne ''){
    $uStart = dateToUsecs $startDate
}
if($endDate -ne ''){
    $uEnd = dateToUsecs $endDate
}
$startTimeMsecs = [int64]($uStart / 1000)
$endTimeMsecs = [int64]($uEnd / 1000)

# outfile
$dateString = ($today).ToString('yyyy-MM-dd')
$outfileName = "threatScanReport-$dateString.csv"

# headings
"""Cluster Name"",""Scan Name"",""Run Date"",""Object Status"",""Object Name"",""Source Name"",""Object Type"",""Environment"",""Affected Files Found"",""File Path"",""File Hash"",""Severity"",""Threat Family"",""Threat Source"",""Threat Category"",""YARA Rule"",""Suppressed"",""Snapshot Date""" | Out-File -FilePath $outfileName -Encoding utf8

function writeRow($values){
    $line = ($values | ForEach-Object { """{0}""" -f ([string]$_ -replace '"', '""') }) -join ','
    $line | Out-File -FilePath $outfileName -Append -Encoding utf8
}

Write-Host "Retrieving Threat Protection scans from $(usecsToDate $uStart) to $(usecsToDate $uEnd)..."

### step 1: get the top level list of threat scans
$scans = @()
$scansToken = $null
while(1){
    $scansUri = "argus/api/v1/public/ioc/scans?startTimeMsecs=$startTimeMsecs&endTimeMsecs=$endTimeMsecs&pageSize=$pageSize"
    if($scanName){
        $scansUri += "&searchTerm=$([uri]::EscapeDataString($scanName))"
    }
    if($scansToken){
        $scansUri += "&paginationToken=$([uri]::EscapeDataString($scansToken))"
    }
    $scansPage = api get -mcm $scansUri
    $scans += $scansPage.scans
    $scansToken = $scansPage.paginationToken
    if(!$scansToken){
        break
    }
}

if(!$scans){
    Write-Host "`nNo Threat Protection scans found in the last $days days`n" -ForegroundColor Yellow
    exit
}

$foundObject = $false

### step 2: drill into the runs for each scan
foreach($scan in $scans){
    $scanId = $scan.id

    $runs = @()
    $runsToken = $null
    while(1){
        $runsUri = "argus/api/v1/public/ioc/scans/$scanId/runs?startTimeMsecs=$startTimeMsecs&endTimeMsecs=$endTimeMsecs&pageSize=$pageSize"
        if($runsToken){
            $runsUri += "&paginationToken=$([uri]::EscapeDataString($runsToken))"
        }
        $runsPage = api get -mcm $runsUri
        $runs += $runsPage.runs
        $runsToken = $runsPage.paginationToken
        if(!$runsToken){
            break
        }
    }

    foreach($run in $runs){

        $runId = $run.id
        $runDate = usecsToDate $run.startTimeUsecs

        ### step 3: drill into each object that was scanned in this run
        foreach($scanObject in $run.objects){
            $object = $scanObject.object
            if($objectName -and $object.name -ne $objectName){
                continue
            }
            $clusterName = getClusterName $object.id
            if($clusterName -notin @(($connectedClusters).name)){
                $clusterName = $object.regionId
            }
            if($clusterNames -and $clusterName -notin @($clusterNames)){
                continue
            }
            $foundObject = $True
            $objectStatus = $scanObject.localSnapshots[0].health.status
            if(!$objectStatus){
                $objectStatus = $object.status
            }
            $envType = $object.environment
            $objType = $object.objectType
            Write-Host "$($scan.name) -> $($object.name) ($runDate)"
            # Write-
            if($objectStatus -notin @('Succeeded', 'SucceededWithWarning')){
                writeRow @($clusterName, $scan.name, $runDate, $objectStatus, $object.name, $object.sourceName, $objType, $envType, '', '', '', '', '', '', '', '', '', '')
                continue
            }

            ### step 4: pull the affected file list for this object/run
            $filesToken = $null
            $filesReported = 0
            $totalFiles = 0
            $rowsWritten = 0

            while(1){
                $filesUri = "argus/api/v1/public/ioc/scans/$scanId/runs/$runId/affected-files?pageSize=$pageSize"
                if($includeSuppressed){
                    $filesUri += '&includeSuppressed=true'
                }
                if($threatFamily){
                    $filesUri += "&threatFamilies=$([uri]::EscapeDataString($threatFamily))"
                }
                if($filesToken){
                    $filesUri += "&paginationToken=$([uri]::EscapeDataString($filesToken))"
                }

                $result = api get -mcm $filesUri
                $totalFiles = $result.total

                foreach($file in $result.affectedFiles){
                    $filesReported += 1
                    if($severity -and $file.severity -notin @($severity)){
                        continue
                    }
                    $snapshotDate = ''
                    if($file.snapshotStartTimeUsecs){
                        $snapshotDate = usecsToDate $file.snapshotStartTimeUsecs
                    }
                    $rowsWritten += 1
                    writeRow @($clusterName, $scan.name, $runDate, $objectStatus, $object.name, $object.sourceName, $objType, $envType, $totalFiles, $file.filePath, $file.fileHash, $file.severity, $file.threatFamily, $file.threatSource, $file.threatCategory, $file.yaraThreatRuleName, $file.suppressed, $snapshotDate)
                }
                Write-Host "  $filesReported of $totalFiles files"
                $filesToken = $result.paginationToken
                if(!$filesToken -or $filesReported -ge $totalFiles){
                    break
                }
            }
            Write-Host ""
            if($rowsWritten -eq 0){
                writeRow @($clusterName, $scan.name, $runDate, $objectStatus, $object.name, $object.sourceName, $objType, $envType, 0, 'no affected files found', '', '', '', '', '', '', '', '')
            }
        }
    }
}

if($objectName -and $foundObject -eq $false){
    Write-Host "`nNo Threat Protection scans found for object $objectName" -ForegroundColor Yellow
}

"`nOutput saved to $outfileName`n"
