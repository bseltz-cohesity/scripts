[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "$($cluster.name)-sqlObjectProtectionStatus-$dateString.csv"
"SQL Server,Database,Protected,Job Name,Policy Name" | Out-File -FilePath $outfileName
$rootSource = api get protectionSources?environment=kSQL

foreach($sqlServer in $rootSource.nodes | Sort-Object -Property {$_.protectionSource.name}){
    $serverName = $sqlServer.protectionSource.name
    $serverId = $sqlServer.protectionSource.id
    $protectedObjects = api get "protectionSources/protectedObjects?environment=kSQL&id=$serverId"
    foreach($instance in $sqlServer.applicationNodes | Sort-Object -Property {$_.protectionSource.name}){
        $instanceName = $instance.protectionSource.name
        foreach($db in $instance.nodes | Sort-Object -Property {$_.protectionSource.name}){
            $protectionStatus = 'FALSE'
            $dbName = $db.protectionSource.name
            $dbShortName = $dbName.split('/')[-1]
            $protectedDb = $protectedObjects | Where-Object {$_.protectionSource.name -eq $dbName}
            if($protectedDb){
                $protectionStatus = 'TRUE'
                $job = $protectedDb.protectionJobs[0]
                $jobName = $job.name
                $policy = $protectedDb.protectionPolicies | Where-Object id -eq $job.policyId
                $policyName = $policy.name
                "{0}  {1} (protected)" -f $serverName, $dbName
                """{0}"",""{1}"",""{2}"",""{3}"",""{4}""" -f $serverName, $dbName, $protectionStatus, $jobName, $policyName | Out-File -FilePath $outfileName -Append
            }else{
                "{0}  {1}" -f $serverName, $dbName
                """{0}"",""{1}"",""{2}""" -f $serverName, $dbName, $protectionStatus | Out-File -FilePath $outfileName -Append
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
