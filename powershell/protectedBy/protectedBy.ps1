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
    [Parameter()][string]$jobType
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

# get root protection sources
$sources = api get protectionSources
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

foreach($source in $sources){
    get_nodes($source)
}

$foundNode = $false
$foundIds = @()

foreach($node in $global:nodes){
    $name = $node.protectionSource.name
    $sourceId = $node.protectionSource.id

    # find matching node
    if($name -like "*$($object)*" -and $sourceId -notin $foundIds){
        $environment = $node.protectionSource.environment

        if($jobType){
            $jobs = $jobs | Where-Object {$_.environment -match $jobType}
        }
        
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

# object not found
if(! $foundNode){
    if($returnJobName){
        return $null
    }
    Write-Host "$object not found"
}
