# view failover settings
$primaryCluster = 'cluster1'
$drCluster = 'cluster2'
$userName = 'myuser'
$domain = 'mydomain.net'
$metaDataPath = '\\my\unc\path'
$policyName = 'My Replication Policy'

# DFS failover settings
$dfsNameSpace = '\\mydomain.net\myshare'

# DNS failover settings
$cnameDomain = 'mydomain.net'

$cname1 = 'sql-ha-1'
$cnameTarget1 = 'cluster2-vip-1'
$cname2 = 'sql-ha-2'
$cnameTarget2 = 'cluster2-vip-2'
$cname3 = 'sql-ha-3'
$cnameTarget3 = 'cluster3-vip-3'

# # clone the replicated view backups
.\viewDRclone.ps1 -vip $drCluster -username $userName -domain $domain -viewList ./myviews.txt -inPath "$metaDataPath\$primaryCluster" -policyName $policyName
# # toggle dfs folder targets
.\dfsFailover.ps1 -nameSpace $dfsNameSpace -shareList .\migratedShares.txt -disableTarget $primaryCluster -enableTarget $drCluster
# # toggle cnames and SPNs
.\cnameFailover.ps1 -cname $cname1 -oldHost $primaryCluster -newHost $drCluster -newRecord $cnameTarget1 -domain $cnameDomain
.\cnameFailover.ps1 -cname $cname2 -oldHost $primaryCluster -newHost $drCluster -newRecord $cnameTarget2 -domain $cnameDomain
.\cnameFailover.ps1 -cname $cname3 -oldHost $primaryCluster -newHost $drCluster -newRecord $cnameTarget3 -domain $cnameDomain
# remove views from source
.\viewDRdelete.ps1 -vip $primaryCluster -username $userName -domain $domain -viewList ./myviews.txt -deleteSnapshots
