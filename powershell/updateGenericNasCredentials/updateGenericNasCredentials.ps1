### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$noPrompt,                     # do not prompt for password
    [Parameter()][string]$tenant,                       # org to impersonate
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][array]$mountPath,
    [Parameter()][string]$mountList,
    [Parameter(Mandatory = $True)][string]$smbUser,
    [Parameter()][string]$smbPassword,
    [Parameter()][switch]$updatePassword
)

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$sourceNames = @(gatherList -Param $mountPAth -FilePath $mountList -Name 'NAS sources' -Required $False)
if(! $updatePassword -and $sourceNames.Count -eq 0){
    Write-Host "No NAS sources specified" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$origSMBuser = $smbUser
if($smbUser -match '\\'){
    $smbDomain, $smbUser = $smbUser -split '\\'
}

if(! $smbPassword){
    $secureString = Read-Host -Prompt "Enter password for $smbDomain\$smbUser" -AsSecureString
    $smbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

$sources = api get "protectionSources/registrationInfo?includeEntityPermissionInfo=true&environments=kGenericNas"

if($updatePassword -and $sourceNames.Count -eq 0){
    $mySources = $sources.rootNodes | Where-Object {$origSMBuser -eq "$($_.registrationInfo.nasMountCredentials.domain)\$($_.registrationInfo.nasMountCredentials.username)" -or $origSMBuser -eq $_.registrationInfo.nasMountCredentials.username}
    $sourceNames = $mySources.rootNode.name
}

foreach($thisSourceName in $sourceNames){
    $mySource = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $thisSourceName}
    if(! $mySource){
        Write-Host "NAS source $thisSourceName not found!" -ForegroundColor Yellow
    }else{
        $sourceInfo = api get "/backupsources?allUnderHierarchy=true&entityId=$($mySource.rootNode.id)&onlyReturnOneLevel=true"
        $updateParams = @{
            'entity' = $sourceInfo.entityHierarchy.entity;
            'entityInfo' = $sourceInfo.entityHierarchy.registeredEntityInfo.connectorParams;
        }
        $updateParams.entityInfo.credentials.nasMountCredentials.username = $smbUser
        setApiProperty -object $updateParams.entityInfo.credentials.nasMountCredentials -name 'domainName' -value $smbDomain
        setApiProperty -object $updateParams.entityInfo.credentials.nasMountCredentials -name 'password' -value $smbPassword
        "Updating $thisSourceName..."
        $null = api put "/backupsources/$($mySource.rootNode.id)" $updateParams    
    }
}



