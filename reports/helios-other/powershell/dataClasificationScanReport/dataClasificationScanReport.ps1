[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][int]$days = 7,
    [Parameter()][string]$scanName,
    [Parameter()][string]$objectName,
    [Parameter()][string]$patternName,
    [Parameter()][ValidateSet('none', 'low', 'medium', 'high')][string[]]$sensitivity,
    [Parameter()][int]$pageSize = 1000
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain 'local' -helios

### determine start and end dates
$today = Get-Date
$uStart = timeAgo $days 'days'
$uEnd = dateToUsecs ($today)
$startTimeMsecs = [int64]($uStart / 1000)
$endTimeMsecs = [int64]($uEnd / 1000)

# outfile
$dateString = ($today).ToString('yyyy-MM-dd')
$outfileName = "dataClassificationReport-$dateString.csv"

# headings
"""Cluster Name"",""Scan Name"",""Run Date"",""Object Status"",""Object Name"",""Object Type"",""Environment"",""Sensitive Files Found"",""File Path"",""Sensitivity"",""Pattern Matched""" | Out-File -FilePath $outfileName -Encoding utf8

Write-Host "Retrieving Data Classification scans from $(usecsToDate $uStart) to $(usecsToDate $uEnd)..."

### step 1: get the top level list of DC scans
$scans = @()
$scansToken = $null
while(1){
    $scansUri = "argus/api/v1/public/dlp/scans?startTimeMsecs=$startTimeMsecs&endTimeMsecs=$endTimeMsecs&pageSize=$pageSize"
    if($scanName){
        $scansUri += "&scanSearchTerm=$scanName"
    }
    if($scansToken){
        $scansUri += "&paginationToken=$scansToken"
    }
    $scansPage = api get -mcm $scansUri
    $scans += $scansPage.scans
    $scansToken = $scansPage.paginationToken
    if(!$scansToken){
        break
    }
}

if(!$scans){
    Write-Host "`nNo Data Classification scans found in the last $days days`n" -ForegroundColor Yellow
    exit
}

$foundObject = $false

### step 2: drill into the runs for each scan
foreach($scan in $scans){
    $scanId = $scan.id

    $runs = @()
    $runsToken = $null
    while(1){
        $runsUri = "argus/api/v1/public/dlp/scans/$scanId/runs?startTimeMsecs=$startTimeMsecs&endTimeMsecs=$endTimeMsecs&pageSize=$pageSize"
        if($runsToken){
            $runsUri += "&paginationToken=$runsToken"
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
            $objectStatus = $scanObject.localSnapshots[0].health.status
            if($objectName -and $object.name -ne $objectName){
                continue
            }
            $foundObject = $True
            $snapshotId = $scanObject.localSnapshots[0].snapshotInfo.snapshotId
            $clusterName = $object.clusterName
            $envType = $object.environment
            $objType = $object.objectType
            Write-Host "$($scan.name) -> $($object.name) ($runDate)"

            if($objectStatus -notin @('Succeeded', 'SucceededWithWarning')){
                """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}""" -f $clusterName, $scan.name, $runDate, $objectStatus, $object.name, $objType, $envType, '', '', '', '' | Out-File -FilePath $outfileName -Append
                continue
            }
            ### step 4: pull the sensitive file list (with pattern matches) for this object/run
            $filesToken = $null
            $filesReported = 0
            $totalFiles = 0
            $rowsWritten = 0

            while(1){
                $body = @{
                    'id'                        = $scanId;
                    'runId'                     = $runId;
                    'objectIds'                 = @($object.id);
                    'includeSensitivityDetails' = $True;
                    'outputFormat'              = 'json';
                    'pageSize'                  = $pageSize;
                    'snapshotIds'               = @($snapshotId)
                }
                if($sensitivity){
                    $body['sensitivities'] = @($sensitivity)
                }
                if($filesToken){
                    $body['paginationToken'] = $filesToken
                }

                $result = api post -mcm "argus/api/v1/public/dlp/sensitive-files" $body
                $totalFiles = $result.total

                foreach($file in $result.sensitiveFiles){
                    $filesReported += 1
                    $fileSensitivity = $file.classificationDetails.sensitivity
                    $patterns = $file.classificationDetails.patternMatches

                    if($patterns -and $patterns.Count -gt 0){
                        foreach($pattern in $patterns){
                            if($patternName -and $pattern.name -notlike "*$patternName*"){
                                continue
                            }
                            $rowsWritten += 1
                            """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}""" -f $clusterName, $scan.name, $runDate, $objectStatus, $object.name, $objType, $envType, $totalFiles, $file.filePath, $fileSensitivity, $pattern.name | Out-File -FilePath $outfileName -Append
                        }
                    }elseif(!$patternName){
                        $rowsWritten += 1
                        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}""" -f $clusterName, $scan.name, $runDate, $objectStatus, $object.name, $objType, $envType, $totalFiles, $file.filePath, $fileSensitivity, '' | Out-File -FilePath $outfileName -Append
                    }
                }
                Write-Host "  $filesReported of $totalFiles files"
                $filesToken = $result.paginationToken
                if(!$filesToken -or $filesReported -ge $totalFiles){
                    break
                }
            }
            Write-Host ""
            if($rowsWritten -eq 0){
                """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}""" -f $clusterName, $scan.name, $runDate, $object.name, $objType, $envType, 0, 'no sensitive files found', '', '' | Out-File -FilePath $outfileName -Append
            }
        }
    }
}

if($objectName -and $foundObject -eq $false){
    Write-Host "`nNo completed Data Classification scans found for object $objectName" -ForegroundColor Yellow
}

"`nOutput saved to $outfileName`n"
