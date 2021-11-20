# metadata collection settings
$primaryCluster = 'cluster1'
$userName = 'myuser'
$domain = 'mydomain.net'
$metaDataPath = '\\my\unc\path'

# save view metadata to DR share
.\viewDRcollect.ps1 -vip $primaryCluster -username $userName -domain $domain -outPath $metaDataPath
