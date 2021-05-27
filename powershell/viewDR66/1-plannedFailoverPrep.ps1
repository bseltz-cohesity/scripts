# general params
$targetCluster = 'clusterb'
$userName = 'myhelios@mydomain.net'
$userDomain = 'local'

# failover the views
# using helios
.\viewDR.ps1 -clusterName $targetCluster -username $userName -domain $userDomain -all -prepareForFailover
# using cluster direct
# .\viewDR.ps1 -vip $targetCluster -username $userName -domain $domainName -all -unplannedFailover
