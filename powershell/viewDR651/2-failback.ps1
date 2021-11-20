# view failback settings
$primaryCluster = 'cluster1'
$drCluster = 'cluster2'
$userName = 'myuser'
$domain = 'mydomain.net'
$metaDataPath = '\\my\unc\path'
$primaryPolicyName = 'My Replication Policy'
# $drPolicyName = 'My Replication Policy'

# DFS failover settings
$dfsNameSpace = '\\mydomain.net\myshare'
$primaryDFSPath = '\\cluster1.mydomain.net'
$drDFSPath = '\\cluster2.mydomain.net'

# DNS failover settings
$cname = 'mycname'
$cnameDomain = 'mydomain.net'
$primaryArecord = 'cluster1.mydomain.net'
$drArecord = 'cluster2.mydomain.net'

# clone the replicated view backups
.\viewDRclone.ps1 -vip $primaryCluster -username $userName -domain $domain -viewList ./myviews.txt -inPath "$metaDataPath\$primaryCluster" -policyName $primaryPolicyName
# toggle dfs folder targets
.\dfsFailover.ps1 -nameSpace $dfsNameSpace -shareList .\migratedShares.txt -disableTarget $drDFSPath -enableTarget $primaryDFSPath
# toggle cnames and SPNs
.\cnameFailover.ps1 -cname $cname -oldHost $drArecord -newHost $primaryArecord -domain $cnameDomain
# remove views from source
.\viewDRdelete.ps1 -vip $drCluster -username $userName -domain $domain -viewList ./myviews.txt -deleteSnapshots
