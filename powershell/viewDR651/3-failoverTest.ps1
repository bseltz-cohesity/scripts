# view failover settings
$primaryCluster = 'cluster1'
$drCluster = 'cluster2'
$userName = 'myuser'
$domain = 'mydomain.net'
$metaDataPath = '\\my\unc\path'
$suffix = '-test'

# clone the replicated view backups
.\viewDRclone.ps1 -vip $drCluster -username $userName -domain $domain -viewList ./myviews.txt -inPath "$metaDataPath\$primaryCluster" -suffix $suffix
