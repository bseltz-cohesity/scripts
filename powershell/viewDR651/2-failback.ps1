# view failback settings
$primaryCluster = 'cluster1.mydomain.net'
$drCluster = 'cluster2.mydomain.net'
$userName = 'myuser'
$domain = 'mydomain.net'
$metaDataPath = '\\my\unc\path'
$policyName = 'My Replication Policy'

# DFS failover settings
$dfsNameSpace = '\\mydomain.net\myshare'

# DNS failover settings
$cname = 'mycname'
$cnameDomain = 'mydomain.net'

# clone the replicated view backups
.\viewDRclone.ps1 -vip $primaryCluster -username $userName -domain $domain -viewList ./myviews.txt -inPath "$metaDataPath\$primaryCluster" -policyName $policyName
# .\viewDRclone.ps1 -vip $primaryCluster -username $userName -domain $domain -viewList ./myviews.txt -inPath "$metaDataPath\$primaryCluster" -policyName $policyName -useApiKey
# toggle dfs folder targets
.\dfsFailover.ps1 -nameSpace $dfsNameSpace -shareList .\migratedShares.txt -disableTarget $drCluster -enableTarget $primaryCluster
# toggle cnames and SPNs
.\cnameFailover.ps1 -cname $cname -oldHost $drCluster -newHost $primaryCluster -domain $cnameDomain
# remove views from source
.\viewDRdelete.ps1 -vip $drCluster -username $userName -domain $domain -viewList ./myviews.txt -deleteSnapshots
# .\viewDRdelete.ps1 -vip $drCluster -username $userName -domain $domain -viewList ./myviews.txt -deleteSnapshots
