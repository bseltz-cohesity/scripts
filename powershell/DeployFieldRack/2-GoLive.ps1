##################################################################
# series of scripts to:
#  - Recover VMs from ProtectionJob
#  - Create Protection Policy that replicates back to garrison
#  - Create Protection Job to protect recovered VMs
#  - Pause source protection job
#  - extend retention of final backup
#  - backup Now 
##################################################################

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$configFile = './config-ve1.ps1', #config file for this environment
    [Parameter()][switch]$goLive,
    [Parameter()][switch]$runNow
)

### load config file for this deployment
. $configFile

### recover VMs to VE
./recoverVMJob.ps1 -vip $remoteVip `
                   -username $remoteUsername `
                   -domain $remoteDomain `
                   -jobName $localJobName `
                   -vCenter $remoteVCenter `
                   -vmDatastore $remoteDatastore `
                   -vmNetwork $remoteNetwork `
                   -vmResourcePool $remoteResourcePool `
                   -vmFolder $remoteVMFolder

if($goLive){
    ### create protectionPolicy
    ./createProtectionPolicy.ps1 -vip $remoteVip `
                                -username $remoteUsername `
                                -domain $remoteDomain `
                                -policyName $remotePolicyName `
                                -daysToKeep $daysToKeep `
                                -replicateTo $localClusterName

    ### create protectionJob
    ./createVMProtectionJob.ps1 -vip $remoteVip `
                                -username $remoteUsername `
                                -domain $remoteDomain `
                                -jobName $remoteJobName `
                                -policyName $remotePolicyName `
                                -startTime $startTime `
                                -vCenterName $remoteVCenter `
                                -storageDomain $remoteStorageDomain `
                                -vmList $vmList

    ### pause source job
    ./pauseProtectionJob.ps1 -vip $localVip `
                             -username $localUsername `
                             -domain $localDomain `
                             -jobName $localJobName

    ### save latest source backup
    ./extendRetention.ps1 -vip $remoteVip `
                          -username $remoteUsername `
                          -jobName $localJobName `
                          -daysToKeep $daysToKeepFinalBackup

    ### run backup now
    if($runNow){
        ./backupRunNow.ps1 -vip $remoteVip `
                           -username $remoteUsername `
                           -domain $remoteDomain `
                           -jobName $remoteJobName `
                           -daysToKeep $daysToKeep
    }
}