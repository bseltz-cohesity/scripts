### Usage: ./summaryReportXLSX.ps1 -vip mycluster -username myuser -domain mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get jobs
$jobs = api get protectionJobs

### get report
$report = api get 'reports/protectionSourcesJobsSummary?allUnderHierarchy=true'

### create excel spreadsheet
$xlsx = Join-Path -Path (Get-Location).Path -ChildPath "summaryReport-$(get-date -UFormat '%Y-%m-%d-%H-%M-%S').xlsx"
write-host "Saving Report to $xlsx..."
$excel = New-Object -ComObject excel.application
$workbook = $excel.Workbooks.Add()
$worksheets=$workbook.worksheets
$sheet=$worksheets.item(1)
$sheet.activate | Out-Null

### Column Headings
$sheet.Cells.Item(1,1) = 'Protection Object Type'
$sheet.Cells.Item(1,2) = 'Protection Object Name'
$sheet.Cells.Item(1,3) = 'Registered Source Name'
$sheet.Cells.Item(1,4) = 'Protection Job Name'
$sheet.Cells.Item(1,5) = 'Num Snapshots'
$sheet.Cells.Item(1,6) = 'Last Run Status'
$sheet.Cells.Item(1,7) = 'Schedule Type'
$sheet.Cells.Item(1,8) = 'Last Run Start Time'
$sheet.Cells.Item(1,9) = 'End Time'
$sheet.Cells.Item(1,10) = 'First Successful Snapshot'
$sheet.Cells.Item(1,11) = 'First Failed Snapshot'
$sheet.Cells.Item(1,12) = 'Last Successful Snapshot'
$sheet.Cells.Item(1,13) = 'Last Failed Snapshot'
$sheet.Cells.Item(1,14) = 'Num Errors'
$sheet.Cells.Item(1,15) = 'Data Read'
$sheet.Cells.Item(1,16) = 'Logical Protected'
$sheet.Cells.Item(1,17) = 'Last Error Message'  

### populate data
$rownum = 2
foreach($source in $report.protectionSourcesJobsSummary){
    $type = $source.protectionSource.environment.Substring(1)
    $name = $source.protectionSource.name
    $parentName = $source.registeredSource
    $jobName = $source.jobName
    $jobId = ($jobs | Where-Object {$_.name -eq $jobName}).id
    $jobUrl = "https://$vip/protection/job/$jobId/details"
    $numSnapshots = $source.numSnapshots
    $lastRunStatus = $source.lastRunStatus.Substring(1)
    $lastRunType = $source.lastRunType
    $lastRunStartTime = usecsToDate $source.lastRunStartTimeUsecs
    $lastRunEndTime = usecsToDate $source.lastRunEndTimeUsecs
    $firstSuccessfulRunTime = usecsToDate $source.firstSuccessfulRunTimeUsecs
    $lastSuccessfulRunTime = usecsToDate $source.lastSuccessfulRunTimeUsecs
    if($lastRunStatus -eq 'Error'){
        $lastRunErrorMsg = $source.lastRunErrorMsg.replace("`r`n"," ").split('.')[0]
        $firstFailedRunTime = usecsToDate $source.firstFailedRunTimeUsecs
        $lastFailedRunTime = usecsToDate $source.lastFailedRunTimeUsecs
    }else{
        $lastRunErrorMsg = ''
        $firstFailedRunTime = ''
        $lastFailedRunTime = ''
    }
    $numDataReadBytes = $source.numDataReadBytes
    $numDataReadBytes = $numDataReadBytes/$numSnapshots
    if($numDataReadBytes -lt 1000){
        $numDataReadBytes = "$numDataReadBytes B"
    }elseif ($numDataReadBytes -lt 1000000) {
        $numDataReadBytes = "$([math]::Round($numDataReadBytes/1024, 2)) KiB"
    }elseif ($numDataReadBytes -lt 1000000000) {
        $numDataReadBytes = "$([math]::Round($numDataReadBytes/(1024*1024), 2)) MiB"
    }elseif ($numDataReadBytes -lt 1000000000000) {
        $numDataReadBytes = "$([math]::Round($numDataReadBytes/(1024*1024*1024), 2)) GiB"
    }else{
        $numDataReadBytes = "$([math]::Round($numDataReadBytes/(1024*1024*1024*1024), 2)) TiB"
    }
    $numLogicalBytesProtected = $source.numLogicalBytesProtected/$numSnapshots
    if($numLogicalBytesProtected -lt 1000){
        $numLogicalBytesProtected = "$numLogicalBytesProtected B"
    }elseif ($numLogicalBytesProtected -lt 1000000) {
        $numLogicalBytesProtected = "$([math]::Round($numLogicalBytesProtected/1024, 2)) KiB"
    }elseif ($numLogicalBytesProtected -lt 1000000000) {
        $numLogicalBytesProtected = "$([math]::Round($numLogicalBytesProtected/(1024*1024), 2)) MiB"
    }elseif ($numLogicalBytesProtected -lt 1000000000000) {
        $numLogicalBytesProtected = "$([math]::Round($numLogicalBytesProtected/(1024*1024*1024), 2)) GiB"
    }else{
        $numLogicalBytesProtected = "$([math]::Round($numLogicalBytesProtected/(1024*1024*1024*1024), 2)) TiB"
    }

    $numErrors = $source.numErrors + $source.numWarnings

    $sheet.Cells.Item($rownum,1) = $type
    $sheet.Cells.Item($rownum,2) = $name
    $sheet.Cells.Item($rownum,3) = $parentName
    $sheet.Cells.Item($rownum,4) = $jobName
    $sheet.Cells.Item($rownum,5) = $numSnapshots
    $sheet.Cells.Item($rownum,6) = $lastRunStatus
    $sheet.Cells.Item($rownum,7) = $lastRunType
    $sheet.Cells.Item($rownum,8) = $lastRunStartTime
    $sheet.Cells.Item($rownum,9) = $lastRunEndTime
    $sheet.Cells.Item($rownum,10) = $firstSuccessfulRunTime
    $sheet.Cells.Item($rownum,11) = $firstFailedRunTime
    $sheet.Cells.Item($rownum,12) = $lastSuccessfulRunTime
    $sheet.Cells.Item($rownum,13) = $lastFailedRunTime
    $sheet.Cells.Item($rownum,14) = $numErrors
    $sheet.Cells.Item($rownum,15) = $numDataReadBytes
    $sheet.Cells.Item($rownum,16) = $numLogicalBytesProtected
    $sheet.Cells.Item($rownum,17) = $lastRunErrorMsg
    if($lastRunStatus -eq 'Warning'){
        $sheet.usedRange.rows($rownum).interior.colorIndex = 36
    }
    if($lastRunStatus -eq 'Error'){
        $sheet.usedRange.rows($rownum).interior.colorIndex = 3
        $sheet.usedRange.rows($rownum).VerticalAlignment = -4160
    }
    $sheet.Hyperlinks.Add(
        $sheet.Cells.Item($rownum,4),
        $jobUrl
    ) | Out-Null
    $rownum += 1
}

### final formatting and save
$sheet.columns.autofit() | Out-Null
$sheet.columns("Q").columnWidth = 100
$sheet.columns("Q").wraptext = $True
$sheet.usedRange.rows(1).Font.Bold = $True
$excel.Visible = $true
$workbook.SaveAs($xlsx,51) | Out-Null