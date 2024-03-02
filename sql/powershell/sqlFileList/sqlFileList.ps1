### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][switch]$protectedOnly
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

"""Server Name"",""DB Name"",""Protected"",""File Path"",""File Extension"",""Size Bytes"",""File Type""" | Tee-Object -Path sqlFiles.csv

$sqlHosts = api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kSQL"

foreach($sqlHost in $sqlHosts.rootNodes | Sort-Object -Property {$_.rootNode.name}){
    $source = api get protectionSources?id=$($sqlHost.rootNode.id)
    $serverName = $source.protectionSource.name
    foreach($instance in $source.applicationNodes | Sort-Object -Property {$_.protectionSource.name}){
        # $instanceName = $instance.protectionSource.name
        foreach($db in $instance.nodes | Sort-Object -Property {$_.protectionSource.name}){
            $dbName = $db.protectionSource.name
            $protected = $False
            if($db.protectedSourcesSummary[0].PSObject.Properties['leavesCount'] -and $db.protectedSourcesSummary[0].leavesCount -eq 1){
                $protected = $True
            }
            if(!$protectedOnly -or $protected -eq $True){
                foreach($dbFile in $db.protectionSource.sqlProtectionSource.dbFiles){
                    $dbFileName = $dbFile.fullPath.split('\')[-1]
                    $ext = ''
                    if($dbFileName.Contains('.')){
                        $ext = $dbFileName.split('.')[-1]
                    }
                    """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}""" -f $serverName, $dbName, $protected, $dbFile.fullPath, $ext, $dbFile.sizeBytes, $dbFile.fileType | Tee-Object -Path sqlFiles.csv -Append
                }
            }
        }
    }
}