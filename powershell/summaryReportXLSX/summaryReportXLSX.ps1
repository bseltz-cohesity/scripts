### Usage: ./summaryReport.ps1 -vip mycluster -username myuser -domain mydomain.net

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

### temp filename
$tempfile = Join-Path -Path (Get-Location).Path -ChildPath "summaryReport-$(get-random).csv"

### get report
api get 'reports/protectionSourcesJobsSummary?outputFormat=csv&allUnderHierarchy=true' | Out-File $tempfile

### open report in Excel
$xlsx = Join-Path -Path (Get-Location).Path -ChildPath "summaryReport-$(get-date -UFormat '%Y-%m-%d-%H-%M-%S').xlsx"
write-host "Saving Report to $xlsx..."
$excel = New-Object -ComObject excel.application
$excel.Visible = $true
$workbook = $excel.Workbooks.Open($tempfile)
$worksheets=$workbook.worksheets
$sheet=$worksheets.item(1)
$sheet.activate | Out-Null
$colA=$sheet.range("A1").EntireColumn
$colrange=$sheet.range("A1")
$xlDelimited = 1
$xlTextQualifier = 1
$colA.texttocolumns($colrange,$xlDelimited,$xlTextQualifier,$false,$false,$false,$true,$false) | Out-Null
$sheet.columns.autofit() | Out-Null
$sheet.columns("A").columnWidth = 23
$sheet.range("A1").Font.Bold = $True
$sheet.usedRange.rows(5).Font.Bold = $True
$stats = $sheet.usedRange.columns(6).cells()
$stats.cells() | ForEach-Object {
    $cell = $_
    $row = $sheet.usedRange.rows($cell.row)
    $stat = $cell.Value()

    if($stat -eq 'Success'){
        $row.interior.colorIndex = 10
        $row.font.colorIndex = 2
    }
    if($stat -eq 'Warning'){
        $row.interior.colorIndex = 6
    }
    if($stat -eq 'Error'){
        $row.interior.colorIndex = 3
        $row.font.colorIndex = 2
    }        
}
$workbook.SaveAs($xlsx,51) | Out-Null
