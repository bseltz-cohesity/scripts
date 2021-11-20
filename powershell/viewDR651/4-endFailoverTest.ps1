# view failover settings
$drCluster = 'cluster2'
$userName = 'myuser'
$domain = 'mydomain.net'
$suffix = '-test'

# remove views from source
.\viewDRdelete.ps1 -vip $drCluster -username $userName -domain $domain -viewList ./myviews.txt -suffix $suffix
