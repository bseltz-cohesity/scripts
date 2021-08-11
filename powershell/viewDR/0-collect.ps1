$sourceCluster = 'mysourcecluster'
$userName = 'myusername'
$domain = 'mydomain.net'
$metaDataPath = '\\my\unc\path'

# save view metadata to DR share
.\viewDRcollect.ps1 -vip $sourceCluster -username $userName -domain $domain -outPath $metaDataPath