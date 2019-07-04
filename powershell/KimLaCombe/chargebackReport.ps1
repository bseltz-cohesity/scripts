#chargebackReport.ps1 -vip [cohesity.lab.com] -username [admin] -start [05/01/2019] -end [05/31/2019] -amt [.10]
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$start,
    [Parameter(Mandatory = $True)][string]$end,
    [Parameter(Mandatory = $True)][string]$amt
)

#open excell
$excel = New-Object -ComObject excel.application
$excel.visible = $True

#add a default workbook
$workbook = $excel.Workbooks.Add()


#give the worksheet a name
$uregwksht= $workbook.Worksheets.Item(1)
$uregwksht.Name = 'Monthly Chargeback'

#Create a Title for the first worksheet and adjust the font
$row = 1
$Column = 1
$uregwksht.Cells.Item($row,$column)= 'Chargeback Report for ' + $start + ' to ' + $end

#merging a few cells on the top row to make the title look nicer
$MergeCells = $uregwksht.Range("A1:H1")
$MergeCells.Select() | Out-Null
$MergeCells.MergeCells = $true
$uregwksht.Cells(1, 1).HorizontalAlignment = -4108

#formatting the title and giving it a font & color
$uregwksht.Cells.Item(1,1).Font.Size = 14
$uregwksht.Cells.Item(1,1).Font.Bold=$True
$uregwksht.Cells.Item(1,1).Font.Name = "Cambria"
$uregwksht.Cells.Item(1,1).Font.ThemeFont = 1
$uregwksht.Cells.Item(1,1).Font.ThemeColor = 4
$uregwksht.Cells.Item(1,1).Font.ColorIndex = 55
$uregwksht.Cells.Item(1,1).Font.Color = 8210719

#create the column headers
$uregwksht.Cells.Item(3,1) = 'Server'
$uregwksht.Cells.Item(3,2) = 'Unique Data'
$uregwksht.Cells.Item(3,3) = 'Cost'

$dateString = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
$outfileName = "Chargeback-$dateString.txt"
$excelfileName = "Chargeback-$dateString.xlsx"
write-host "Saving Chargeback Report as $excelfileName..."

#create outfile and add header
Add-Content $outfileName "name,uniqueData,cost" -Encoding Ascii


### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### Convert time
$uStart = ([int][double]::Parse((Get-Date -Date $start -UFormat %s))).ToString() + "000000"
$uEnd = ([int][double]::Parse((Get-Date -Date $end -UFormat %s))).ToString() + "000000"

$allInfo = api get /reports/objects/storage 
foreach ($allInfoItem in $allinfo) {
    $server = $allInfoItem.name
    $snapshots = $allInfoItem.dataPoints
    $maxsize = 0
    foreach ($snapshotsItem in $snapshots) {
        If ($snapshotsItem.snapshotTimeUsecs -lt $uEnd -And $snapshotsItem.snapshotTimeUsecs -gt $uStart) {
            if($snapshotsItem.primaryPhysicalSizeBytes -gt $maxsize){
                $maxsize = $snapshotsItem.primaryPhysicalSizeBytes
            }
        }
    }
    $maxsize = $maxsize/(1024*1024*1024) # GB
    $chargeback = $maxsize * $amt
    $exportList = $server + "," + $maxsize + "," + $chargeback | Out-File $outFileName -Append ascii
    }


#sorting the server list by name
$lines = Get-Content $outFileName
@($lines[0], ($lines[1 .. ($lines.Count -1)] | Sort-Object )) | Set-Content $outFileName


#getting the external data from a CSV file
$records = Import-Csv -Path $outfileName

#i used row 1 for the title then left a blank row & use row 3 for the column headers
# i chose to start with the data from row 4 hence the $i is set to 4
$i = 4 

# the .appendix to $record refers to the column header in the csv file 
foreach($record in $records) 
{
    if($record.name -ne 'name'){
        $excel.cells.item($i,1) = $record.name
        $excel.cells.item($i,2) = [math]::Round($record.uniqueData,2)
        $excel.cells.item($i,3) = [math]::Round($record.cost,2)
        $i++ 
    }
} 

#adjusting the column width so all data's properly visible
$usedRange = $uregwksht.UsedRange	
$usedRange.EntireColumn.AutoFit() | Out-Null

#saving & closing the file
$workbook.SaveAs($excelfileName)
Remove-Item $outfileName
#$excel.Quit()