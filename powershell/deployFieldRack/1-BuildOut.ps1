##################################################################
# series of scripts to:
#  - Establish replication to new VE
#  - Create Protection Policy that replcates to new VE
#  - Create Protection Job for VMs
##################################################################

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$configFile = './config-ve1.ps1', #config file for this environment
    [Parameter()][switch]$runNow # run first backup immediately
)

### load config file for this deployment
. $configFile

### enable replication
./addRemoteCluster.ps1 -localVip $localVip `
                       -localUsername $localUsername `
                       -localDomain $localDomain `
                       -localStorageDomain $localStorageDomain `
                       -remoteVip $remoteVip `
                       -remoteUsername $remoteUsername `
                       -remoteDomain $remoteDomain `
                       -remoteStorageDomain $remoteStorageDomain

### create protectionPolicy
./createProtectionPolicy.ps1 -vip $localVip `
                             -username $localUsername `
                             -domain $localDomain `
                             -policyName $localPolicyName `
                             -daysToKeep $daysToKeep `
                             -replicateTo $remoteClusterName

### create protectionJob
./createVMProtectionJob.ps1 -vip $localVip `
                            -username $localUsername `
                            -domain $localDomain `
                            -jobName $localJobName `
                            -policyName $localPolicyName `
                            -startTime $startTime `
                            -vCenterName $localVCenter `
                            -storageDomain $localStorageDomain `
                            -vmList $vmList

### run first backup now
if($runNow){
    ./backupRunNow.ps1 -vip $localVip `
                       -username $localUsername `
                       -domain $localDomain `
                       -jobName $localJobName `
                       -daysToKeep $daysToKeep
}