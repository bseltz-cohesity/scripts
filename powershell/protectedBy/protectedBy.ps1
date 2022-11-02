### usage: ./protectedBy.ps1 -vip 192.168.1.198 -username admin -domain local -object myvm

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$object,
    [Parameter()][switch]$returnJobName,
    [Parameter()][string]$jobType,
    [Parameter()][switch]$quickSearch
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# get protection jobs
$jobs = api get protectionJobs

if($jobType){
    $jobs = $jobs | Where-Object {$_.environment -match $jobType}
}

$global:nodes = @()

# get flat list of protection source nodes
function get_nodes($obj){
    if($obj.PSObject.Properties['nodes']){
        foreach($node in $obj.nodes){
            get_nodes($node)
        }
    }else{
        $global:nodes += $obj
    }
}

$foundNode = $false
$foundIds = @()

if($quickSearch){
    $search = api get /searchvms?vmName=$object
    $searchResults = $search.vms | Where-Object {$_.vmDocument.objectName -eq $object -or $_.vmDocument.objectAliases -eq $object}
    $searchResults = $searchResults | Where-Object {$_.vmDocument.objectId.jobId -in $jobs.id}
    $versions = @()
    foreach($searchResult in $searchResults){
        foreach($version in $searchResult.vmDocument.versions){
            setApiProperty -object $version -name vmDocument -value $searchResult.vmDocument
            setApiProperty -object $version -name registeredSource -value $searchResult.registeredSource
            $versions = @($versions + $version)
        }
    }
    $versions = $versions | Sort-Object -Property {$_.instanceId.jobStartTimeUsecs} -Descending
    if($versions.Count -gt 0){
        $jobName = $versions[0].vmDocument.jobName
        $foundNode = $True
        $job = $jobs | Where-Object {$_.id -eq $version.vmDocument.objectId.jobId}
        if($returnJobName){
            return $($job.name) 
        }
        Write-Host ("({0}) {1}" -f $job.environment, $job.name)
    }
}else{
    # get root protection sources
    $sources = api get protectionSources

    foreach($source in $sources){
        get_nodes($source)
    }

    foreach($node in $global:nodes){
        $name = $node.protectionSource.name
        $sourceId = $node.protectionSource.id

        # find matching node
        if($name -like "*$($object)*" -and $sourceId -notin $foundIds){
            $environment = $node.protectionSource.environment

            # find job that protects this node
            $job = $jobs | Where-Object {$_.sourceIds -eq $sourceId }

            if($job){
                $protectionStatus = "is protected by $($job.name)"
            }else{
                $protectionStatus = 'is unprotected'
            }
            
            # report result
            if($environment -ne 'kAgent'){
                if($returnJobName){
                    return $($job.name) 
                }
                Write-Host ("({0}) {1} ({2}) {3}" -f $environment, $name, $sourceId, $protectionStatus)
                $foundNode = $True
                $foundIds += $sourceId
            }
        }
    }
}


# object not found
if(! $foundNode){
    if($returnJobName){
        return $null
    }
    Write-Host "$object not found"
}
