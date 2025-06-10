# usage: ./excludeMailboxes.ps1 -vip mycluster -username myusername -jobName 'My Job' -exclusionList ./excludedMailboxes.txt

# process commandline arguments
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
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to exclude mailboxes from
    [Parameter()][array]$users = $null,  # comma separated list of users to exclude
    [Parameter()][string]$userList = ''  # text file of users to exclude
)

# gather list of users to add to job
$exclusions = @()
foreach($user in $users){
    $exclusions += $user
}
if ('' -ne $userList){
    if(Test-Path -Path $userList -PathType Leaf){
        $users = Get-Content $userList
        foreach($user in $users){
            $exclusions += $user
        }
    }else{
        Write-Warning "User list $userList not found!"
        exit
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

# get the protectionJob
$job = (api get -v2 data-protect/protection-groups?environments=kO365Exchange).protectionGroups | Where-Object {$_.name -ieq $jobName}
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
}

$cluster = api get cluster
if($cluster.clusterSoftwareVersion -gt '6.8'){
    $environment = 'kO365Exchange'
}else{
    $environment = 'kO365'
}
if($cluster.clusterSoftwareVersion -lt '6.6'){
    $entityTypes = 'kMailbox,kUser,kGroup,kSite,kPublicFolder'
}else{
    $entityTypes = 'kMailbox,kUser,kGroup,kSite,kPublicFolder,kO365Exchange,kO365OneDrive,kO365Sharepoint'
}

$sourceId = $job.office365Params.sourceId
$rootSource = api get "protectionSources/rootNodes?environments=kO365&id=$sourceId"
$source = api get "protectionSources?id=$($rootSource.protectionSource.id)&excludeOffice365Types=$entityTypes&allUnderHierarchy=false"
$mailboxesNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'users'}

Write-Host "Discovering mailboxes..."

$nameIndex = @{}
$smtpIndex = @{}
$nodeIdIndex = @()
$lastCursor = 0

$mailboxes = api get "protectionSources?pageSize=50000&nodeId=$($mailboxesNode.protectionSource.id)&id=$($mailboxesNode.protectionSource.id)&allUnderHierarchy=false&hasValidMailbox=true&useCachedData=false"
$cursor = $mailboxes.entityPaginationParameters.beforeCursorEntityId
if($mailboxesNode.protectionSource.id -in $protectedIndex){
    $autoProtected = $True
}

# enumerate mailboxes
while(1){
    foreach($node in $mailboxes.nodes){
        $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
        $lastCursor = $node.protectionSource.id
    }
    if($cursor){
        $mailboxes = api get "protectionSources?pageSize=50000&nodeId=$($mailboxesNode.protectionSource.id)&id=$($mailboxesNode.protectionSource.id)&allUnderHierarchy=false&hasValidMailbox=true&useCachedData=false&afterCursorEntityId=$cursor"
        $cursor = $mailboxes.entityPaginationParameters.beforeCursorEntityId
    }else{
        break
    }
    # patch for 6.8.1
    if($mailboxes.nodes -eq $null){
        if($cursor -gt $lastCursor){
            $node = api get protectionSources?id=$cursor
            $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
            $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
            $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
            $lastCursor = $node.protectionSource.id
        }
    }
    if($cursor -eq $lastCursor){
        break
    }
}

$nodeIdIndex = @($nodeIdIndex | Sort-Object -Unique)
Write-Host "$($nodeIdIndex.Count) mailboxes discovered"

$exclusionsAdded = $false
foreach ($excludeUser in $exclusions){
    if($excludeUser -in $nameIndex.Keys){
        $nodeId = $nameIndex[$excludeUser]
    }elseif($excludeUser -in $smtpIndex.Keys){
        $nodeId = $smtpIndex[$excludeUser]
    }else{
        Write-host "Can't find user $excludeUser - skipping" -ForegroundColor Yellow
        continue
    }
    if($nodeId -in $job.office365Params.objects.id){
        $exclusionsAdded = $True
        $job.office365Params.objects = @($job.office365Params.objects | Where-Object {$_.id -ne $nodeId})
        write-host "Unprotecting $excludeUser" -ForegroundColor Green
    }else{
        write-host "$excludeUser not found in job" -ForegroundColor Green
    }
}

if($exclusionsAdded){
    if(@($job.office365Params.objects).Count -lt 1){
        Write-Host "Job '$jobName' will be empty, please just delete the job"
    }else{
        $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
    }
}

