### usage: ./chargebackReport.ps1 -vip mycluster -username myusername -domain mydomain.net -start '2019-07-14' -end '2019-07-21' -amt .10 -smtpServer 192.168.1.95 -sendTo myusername@mydomain.net -sendFrom reports@mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][string]$start = '', # start of date range 
    [Parameter()][string]$end = '', # end of date range
    [Parameter(Mandatory = $True)][string]$amt, # cost per GB of storage
    [Parameter(Mandatory = $True)][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter(Mandatory = $True)][array]$sendTo, #send to address
    [Parameter(Mandatory = $True)][string]$sendFrom #send from address
)

function td($data, $color, $wrap='', $align='LEFT'){
    '<td ' + $wrap + ' colspan="1" bgcolor="#' + $color + '" valign="top" align="' + $align + '" border="0"><font size="2">' + $data + '</font></td>'
}

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### Convert time
if($start -eq ''){
    $startDate = (get-date).AddMonths(-1)
}else{
    $startDate = (Get-Date -Date $start)
}
$uStart = dateToUsecs $startDate

if($end -eq ''){
    $endDate = (get-date)
}else{
    $endDate  = (Get-Date -Date $end)
}
$uEnd = dateToUsecs $endDate

### gather storage statistics
write-host "Gathering storage statistics..."
$allInfo = api get /reports/objects/storage?startTimeUsecs=$uStart`&endTimeUsecs=$uEnd | Sort-Object -Property name

### html start
$html = '<html>'
$title = 'Chargeback Report for ' + $startDate.ToString('yyyy-MM-dd') + ' to ' + $endDate.ToString('yyyy-MM-dd')

$html += '<div style="font-family: Roboto,RobotoDraft,Helvetica,Arial,sans-serif;font-size: small;"><font face="Tahoma" size="+3" color="#000080">
<center>' + $title + '</center>
</font>
<hr>
Report generated on ' + (get-date) + '<br>
<br></div>'

$html += '<table border="1" cellpadding="4" cellspacing="0" style="font-family: Roboto,RobotoDraft,Helvetica,Arial,sans-serif;font-size: small;">
<tbody><tr bgcolor="#FFFFFF">'

$headings = @('Server',
              'Unique Data', 
              'Cost')

foreach($heading in $headings){
    $html += td $heading 'CCCCCC' '' 'LEFT'
}
$html += '</tr>'
$nowrap = 'nowrap'

### open excel
$excel = New-Object -ComObject excel.application
$excel.visible = $True

### add a default workbook
$workbook = $excel.Workbooks.Add()

### give the worksheet a name
$uregwksht= $workbook.Worksheets.Item(1)
$uregwksht.Name = 'Monthly Chargeback'

### Create a Title for the first worksheet and adjust the font
$uregwksht.Cells.Item(1,1)= $title

### merging a few cells on the top row to make the title look nicer
$MergeCells = $uregwksht.Range("A1:H1")
$MergeCells.Select() | Out-Null
$MergeCells.MergeCells = $true
$uregwksht.Cells(1,1).HorizontalAlignment = -4108
$uregwksht.Cells.Item(1,1).Font.Size = 14
$uregwksht.Cells.Item(1,1).Font.Bold=$True
$uregwksht.Cells.Item(1,1).Font.Name = "Cambria"
$uregwksht.Cells.Item(1,1).Font.ThemeFont = 1
$uregwksht.Cells.Item(1,1).Font.ThemeColor = 4
$uregwksht.Cells.Item(1,1).Font.ColorIndex = 55
$uregwksht.Cells.Item(1,1).Font.Color = 8210719

### create the column headers
$uregwksht.Cells.Item(3,1) = 'Server'
$uregwksht.Cells.Item(3,2) = 'Unique Data'
$uregwksht.Cells.Item(3,3) = 'Cost'
$uregwksht.Rows(3).Font.Bold=$True

$dateString = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
$excelfileName = Join-Path -Path (get-location).path -ChildPath "Chargeback-$dateString.xlsx"

$rownum = 4
$color = 'FFFFFF'

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
    $html += '<tr>'
    $excel.cells.item($rownum,1) = $server
    $excel.cells.item($rownum,2) = [math]::Round($maxsize,2)
    $excel.cells.item($rownum,3) = [math]::Round($chargeback,2)
    $html += td $server $color $nowrap
    $html += td ([math]::Round($maxsize,2)) $color $nowrap
    $html += td ([math]::Round($chargeback,2)) $color $nowrap
    $html += '</tr>'
    $rownum += 1
}
$html += '</tbody></table></html>'

### adjusting the column width so all data's properly visible
$usedRange = $uregwksht.UsedRange	
$usedRange.EntireColumn.AutoFit() | Out-Null

### saving & closing the file
write-host "Saving Chargeback Report as $excelfileName..."
$workbook.SaveAs($excelfileName)
$workbook.close()
$excel.quit()

### send email report
write-host "sending report to $([string]::Join(", ", $sendTo))"

foreach($toaddr in $sendTo){
    Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "ChargebackReport" -BodyAsHtml $html -Attachments $excelfileName
}

Remove-Item -Path $excelfileName
