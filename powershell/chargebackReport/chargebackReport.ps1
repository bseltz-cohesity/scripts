#./chargebackReport.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -start 05/01/2019 -end 05/31/2019 -amt .10 [ -prefix demo, test ] -sendTo myuser@mydomain.net, anotheruser@mydomain.net -smtpServer 192.168.1.95 -sendFrom backupreport@mydomain.net
 
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$start,
    [Parameter(Mandatory = $True)][string]$end,
    [Parameter(Mandatory = $True)][string]$amt,
    [Parameter()][array]$prefix = 'ALL', #report jobs with 'prefix' only
    [Parameter(Mandatory = $True)][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter(Mandatory = $True)][array]$sendTo, #send to address
    [Parameter(Mandatory = $True)][string]$sendFrom #send from address
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### Convert time
$uStart = ([int][double]::Parse((Get-Date -Date $start -UFormat %s))).ToString() + "000000"
$uEnd = ([int][double]::Parse((Get-Date -Date $end -UFormat %s))).ToString() + "000000"

$title = "($([string]::Join(", ", $prefix.ToUpper()))) Chargeback Report ($start - $end)"

$csvFileName = "$([string]::Join("_", $prefix.ToUpper()))_Chargeback_Report_$start_$end.csv"

$date = (get-date).ToString()

"Object,Size,Cost" | Out-File $csvFileName -Encoding ascii

$html = '<html>
<head>
    <style>
        p {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        span {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        

        table {
            font-family: Arial, Helvetica, sans-serif;
            color: #333333;
            font-size: 0.75em;
            border-collapse: collapse;
            width: 100%;
        }

        tr {
            border: 1px solid #F1F1F1;
        }

        td,
        th {
            width: 33%;
            text-align: left;
            padding: 6px;
        }

        tr:nth-child(even) {
            background-color: #F1F1F1;
        }
    </style>
</head>
<body>
    
    <div style="margin:15px;">
            <img src="https://www.cohesity.com/wp-content/themes/cohesity/refresh_2018/templates/dist/images/footer/footer-logo-green.png" style="width:180px">
        <p style="margin-top: 15px; margin-bottom: 15px;">
            <span style="font-size:1.3em;">'

$html += $title
$html += '</span>
<span style="font-size:0.75em; text-align: right; padding-top: 8px; padding-right: 2px; float: right;">'
$html += $date
$html += '</span>
</p>
<table>
<tr>
        <th>Object Name</th>
        <th>Size</th>
        <th>Cost</th>
      </tr>'

$allInfo = api get /reports/objects/storage 

$totalSize = 0
$totalCost = 0

foreach ($allInfoItem in $allinfo) {
    $server = $allInfoItem.name
    $jobName = $allInfoItem.jobName
    $includeRecord = $false
    foreach($pre in $prefix){
        if ($jobName.tolower().startswith($pre.tolower()) -or $prefix -eq 'ALL') {
            $includeRecord = $true
        }
    }
    if($includeRecord){
        $snapshots = $allInfoItem.dataPoints
        $maxsize = 0
        foreach ($snapshotsItem in $snapshots) {
            If ($snapshotsItem.snapshotTimeUsecs -lt $uEnd -And $snapshotsItem.snapshotTimeUsecs -gt $uStart) {
                if($snapshotsItem.primaryPhysicalSizeBytes -gt $maxsize){
                    $maxsize = $snapshotsItem.primaryPhysicalSizeBytes
                }
            }
        }
        $maxsize = [math]::Round($maxsize/(1024*1024*1024),2)
        $chargeback = [math]::Round($maxsize * $amt,2)
        $totalSize += $maxsize
        $totalCost += $chargeback
        "$server,$maxsize,$chargeback" | Out-File $csvFileName -Append ascii
        $html += "<tr>
            <td>$server</td>
            <td>$maxsize</td>
            <td>$chargeback</td>
        </tr>"
    }
}

"Total,$totalSize,$totalCost" | Out-File $csvFileName -Append ascii

$html += "<tr>
<td>Total</td>
<td>$totalSize</td>
<td>$totalCost</td>
</tr>
</table>                
</div>
</body>
</html>"

$html | out-file chargeBackReport.html

write-host "sending report to $([string]::Join(", ", $sendTo))"
### send email report
foreach($toaddr in $sendTo){
    Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title -BodyAsHtml $html -Attachments $csvFileName
}

