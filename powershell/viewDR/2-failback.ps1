# clone the replicated view backups
./viewDRclone.ps1 -vip mycluster -username admin [ -domain local ] -inPath \\myDRcluster\viewDR\mycluster -all
# toggle dfs folder targets
.\dfsFailover.ps1 -nameSpace \\mydomain.net\shares -shareList .\migratedShares.txt -disableTarget \\myDRcluster.mydomain.net -enableTarget \\mycluster.mydomain.net
# toggle cnames and SPNs
.\cnameFailover.ps1 -cname mynas -oldHost myDRcluster -newHost mycluster -domain mydomain.net
# remove views from source
./viewDRdelete.ps1 -vip myDRcluster -username admin [ -domain local ] -inPath \\myDRcluster\viewDR\mycluster -all
