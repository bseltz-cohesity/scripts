# clone the replicated view backups
./viewDRclone.ps1 -vip myDRcluster -username admin [ -domain local ] -inPath \\myDRcluster\viewDR\mycluster -all
# toggle dfs folder targets
# .\dfsFailover.ps1 -nameSpace \\mydomain.net\shares -shareList .\migratedShares.txt -disableTarget \\myCluster.mydomain.net -enableTarget \\myDRcluster.mydomain.net
# toggle cnames and SPNs
# .\cnameFailover.ps1 -cname mynas -oldHost mycluster -newHost myDRcluster -domain mydomain.net
# remove views from source
# ./viewDRdelete.ps1 -vip mycluster -username admin [ -domain local ] -inPath \\myDRcluster\viewDR\mycluster -all
