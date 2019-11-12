    ### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter()][string]$serverList, #Servers to add as physical source
    [Parameter()][string]$server
)

if($serverList){
    $servers = get-content $serverList
}elseif($server){
    $servers = @($server)
}else{
    Write-Warning "No Servers Specified"
    exit
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get protection sources
$sources = api get protectionSources/registrationInfo

### register server as SQL
foreach ($server in $servers){
    $server = $server.ToString()

    if (! $($sources.rootNodes | Where-Object { $_.rootNode.name -eq $server -and $_.applications.environment -eq 'kSQL' })) {
        "Registering $server as SQL protection source..."
        $phys = api get protectionSources?environments=kPhysical
        $sourceId = ($phys.nodes | Where-Object { $_.protectionSource.name -ieq $server }).protectionSource.id
        if ($sourceId) {
            $regSQL = @{"ownerEntity" = @{"id" = $sourceId}; "appEnvVec" = @(3)}
            $null = api post /applicationSourceRegistration $regSQL
        }
        else {
            Write-Warning "$server is not yet registered as a protection source"
        }
    }
}
