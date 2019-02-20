[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$dateString = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
$outfileName = "RecoverPoints-$dateString.csv"
"JobName,JobType,ProtectedObject,RecoveryDate,RunURL" | Out-File -FilePath $outfileName

### find recoverable objects
$ro = api get /searchvms

$environments = @('Unknown', 'VMware' , 'HyperV' , 'SQL' , 'View' , `
                  'RemoteAdapter' , 'Physical' , 'Pure' , 'Azure' , 'Netapp' , `
                  'Agent' , 'GenericNas' , 'Acropolis' , 'PhysicalFiles' , `
                  'Isilon' , 'KVM' , 'AWS' , 'Exchange' , 'HyperVVSS' , `
                  'Oracle' , 'GCP' , 'FlashBlade' , 'AWSNative' , 'VCD' , `
                  'O365' , 'O365Outlook' , 'HyperFlex' , 'GCPNative', `
                  'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', `
                  'Unknown', 'Unknown', 'Unknown') 

if($ro.count -gt 0){
    $ro.vms | Sort-Object -Property {$_.vmDocument.jobName}, {$_.vmDocument.objectName } | ForEach-Object {
        $doc = $_.vmDocument
        $jobId = $doc.objectId.jobId
        $jobName = $doc.jobName
        $objName = $doc.objectName
        $objType = $environments[$doc.registeredSource.type]
        $objSource = $doc.registeredSource.displayName
        $objAlias = ''
        if('objectAliases' -in $doc.PSobject.Properties.Name){
            $objAlias = $doc.objectAliases[0]
            if($objAlias -eq "$objName.vmx" ){
                $objAlias = ''
            }
            if($objType -eq 'VMware' ){
                $objAlias = ''
            }
        }
        if($objType -eq 'View'){
            $objSource = ''
        }
        if($objAlias -ne ''){
            $objName = "$objName on $objAlias"
        }
        "{0}({1}) {2}" -f $jobName, $objType, $objName
        $doc.versions | ForEach-Object {
            $runId = $_.instanceId.jobInstanceId
            $startTime = $_.instanceId.jobStartTimeUsecs
            $runURL = "https://$vip/protection/job/$jobId/run/$runId/$startTime/protection"
            "`t{0}`t{1}" -f $(usecsToDate $startTime), $runURL
            "$jobName,$objType,$objName,$(usecsToDate $startTime), $runURL" | Out-File -FilePath $outfileName -Append
        }
    }
    "Report Saved to $outFileName"
}




