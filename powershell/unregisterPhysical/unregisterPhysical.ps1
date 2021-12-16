### usage: ./new-PhysicalSource.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -server win2016.mydomain.com

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter()][string]$serverName, #Server to add as physical source
    [Parameter()][string]$serverList
)

# gather view list
if($serverList){
    $servers = get-content $serverList
}elseif($serverName){
    $servers = @($serverName)
}else{
    Write-Host "No servers Specified" -ForegroundColor Yellow
    exit
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -quiet

foreach($server in $servers){
    $server = [string]$server
    $registeredSource = (api get "protectionSources/registrationInfo?includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false").rootNodes | Where-Object { $_.rootNode.name -eq $server }
    if($registeredSource){
        "Unregistering $server..."
        $null = api delete protectionSources/$($registeredSource.rootNode.id)
    }else{
        "$server not registered"
    }
}
