### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter(Mandatory = $True)][string]$sourceName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

$sources = api get 'protectionSources/registrationInfo?allUnderHierarchy=false'

function getObjectId($sourceName){
    foreach($source in $sources.rootNodes){
        if($source.rootNode.name -eq $sourceName){
            return $source.rootNode.id
        }
    }
    return $null
}

function waitForRefresh($server){
    $authStatus = ""
    while($authStatus -ne 'Finished'){
        $rootFinished = $false
        $appsFinished = $false
        Start-Sleep 2
        $rootNode = (api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kPhysical").rootNodes | Where-Object {$_.rootNode.name -eq $server}
        if($rootNode.registrationInfo.authenticationStatus -eq 'kFinished'){
            $rootFinished = $True
        }
        if($rootNode.registrationInfo.PSObject.Properties['registeredAppsInfo']){
            foreach($app in $rootNode.registrationInfo.registeredAppsInfo){
                if($app.authenticationStatus -eq 'kFinished'){
                    $appsFinished = $True
                }else{
                    $appsFinished = $false
                }
            }
        }else{
            $appsFinished = $True
        }
        if($rootFinished -and $appsFinished){
            $authStatus = 'Finished'
        }
    }
    return $rootNode.rootNode.id
}

$objectId = getObjectId $sourceName
if($objectId){
    write-host "refreshing $sourceName..."
    $result = api post protectionSources/refresh/$($objectId)
    $result = waitForRefresh($sourceName)
}else{
    write-host "$sourceName not found" -ForegroundColor Yellow
}
