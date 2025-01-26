# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][array]$rdsName,
    [Parameter()][string]$rdsList,
    [Parameter()][ValidateSet('kAuroraCluster','kRDSInstance')][string]$rdsType,
    [Parameter()][string]$dbEngine,
    [Parameter()][switch]$update,
    [Parameter()][string]$rdsUser,
    [Parameter()][string]$rdsPassword,
    [Parameter()][string]$realmName,
    [Parameter()][string]$realmDnsAddress,
    [Parameter()][ValidateSet('credentials', 'iam', 'kerberos')][string]$authType = 'credentials'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# gather required credentials
if($update){
    if(!$rdsUser -or ($authType -ne 'iam' -and !$rdsPassword) -or ($authType -eq 'kerberos' -and (!$realmName -or !$realmDnsAddress))){
        Write-Host "`nPrompting for required RDS credentials:" -ForegroundColor Yellow
        if(!$rdsUser){
            $rdsUser = Read-Host -Prompt "        RDS Username"
        }
        if($authType -ne 'iam'){
            if(!$rdsPassword){
                $confirmPassword = '1'
                $rdsPassword = '2'
                while($confirmPassword -ne $rdsPassword){
                    $secureString = Read-Host -Prompt "        RDS Password" -AsSecureString
                    $rdsPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
                    $secureString = Read-Host -Prompt "Confirm RDS Password" -AsSecureString
                    $confirmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
                }
            }
        }
        if($authType -eq 'kerberos'){
            if(!$realmName){
                $realmName = Read-Host -Prompt "          Realm Name"
            }
            if(!$realmDnsAddress){
                $realmDnsAddress = Read-Host -Prompt "   Realm DNS Address"
            }
        }
        Write-Host ''
    }
}

$outfileName = "rds-instances.csv"
"""Name"",""Type"",""DB Engine""" | Out-File -FilePath $outfileName 

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

$rdsNames = @(gatherList -Param $rdsName -FilePath $rdsList -Name 'RDS Instances' -Required $false)

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

# find registered source
$sources = api get -mcmv2 "data-protect/sources?regionIds=$regionList&environments=kAWS"
$source = $sources.sources | Where-Object name -eq $sourceName
if(! $source){
    Write-Host "AWS source $sourceName not found" -ForegroundColor Yellow
    exit 1
}
$sourceId = $source.sourceInfoList[0].sourceId
$regionId = $source.sourceInfoList[0].regionId
$thisSource = api get "protectionSources?useCachedData=false&includeVMFolders=true&includeSystemVApps=true&includeExternalMetadata=true&includeEntityPermissionInfo=true&id=$sourceId&excludeTypes=kResourcePool&excludeAwsTypes=kEC2Instance,kTag,kS3Bucket,kS3Tag&environment=kAWS&allUnderHierarchy=false" -region $regionId

# find all rds instances
$regionNodes = $thisSource.nodes | Where-Object {$_.protectionSource.awsProtectionSource.type -eq 'kRegion'}
$azNodes = $regionNodes.nodes | Where-Object {$_.protectionSource.awsProtectionSource.type -eq 'kAvailabilityZone'}
$rdsNodes = $azNodes.nodes | Where-Object {$_.protectionSource.awsProtectionSource.type -in @('kRDSInstance', 'kAuroraCluster') -and $_.protectionSource.awsProtectionSource.dbEngineId -match 'postgres'}

# filter on instance type
if($rdsType){
    $rdsNodes = $rdsNodes | Where-Object {$_.protectionSource.awsProtectionSource.type -eq $rdsType}
}

# filter on DB Engine
if($dbEngine){
    $rdsNodes = $rdsNodes | Where-Object {$_.protectionSource.awsProtectionSource.dbEngineId -eq $dbEngine}
}

# filter on instance name
if($rdsNames.Count -gt 0){
    $rdsNodes = $rdsNodes | Where-Object {$_.protectionSource.name -in $rdsNames}
    $notFound = $rdsNames | Where-Object {$_ -notin $rdsNodes.protectionSource.name}
    # report not found instances
    $notFound | Sort-Object | ForEach-Object{
        Write-Host "$_ not found" -ForegroundColor Yellow
    }
}

if($update){
    $rdsNodes | Sort-Object -Property {$_.protectionSource.name} | ForEach-Object{
        $name = $_.protectionSource.name
        $objectId = $_.protectionSource.id
        $dbEngine = $_.protectionSource.awsProtectionSource.dbEngineId
        $type = $_.protectionSource.awsProtectionSource.type

        $metaParams = @{
            "sourceId" = $thisSource.protectionSource.id;
            "entityList" = @(
                @{
                    "entityId" = $objectId;
                    "awsParams" = @{}
                }
            )
        }
    
        if($type -eq 'kAuroraCluster'){
            $metaParams.entityList[0].awsParams['auroraParams'] = @{}
            $params = $metaParams.entityList[0].awsParams['auroraParams']
        }else{
            $metaParams.entityList[0].awsParams['rdsParams'] = @{}
            $params = $metaParams.entityList[0].awsParams['rdsParams']
        }
        $params['dbEngineId'] = $dbEngine
        $params['metadataList'] = @(
            @{
                "metadataType" = 'Credentials';
                "standardCredentials" = @{
                    "username" = $rdsUser;
                }
            }
        )
        if($authType -eq 'credentials'){
            $params['metadataList'][0]['standardCredentials']['authType'] = 'kStandardCredentials'
            $params['metadataList'][0]['standardCredentials']['password'] = $rdsPassword
        }elseif($authType -eq 'iam'){
            $params['metadataList'][0]['standardCredentials']['authType'] = 'kUseIAMRole'
            $params['metadataList'][0]['standardCredentials']['password'] = $null
        }elseif($authType -eq 'kerberos'){
            $params['metadataList'][0]['standardCredentials']['authType'] = 'kKerberos'
            $params['metadataList'][0]['standardCredentials']['password'] = $rdsPassword
            $params['metadataList'][0]['standardCredentials']['realmName'] = $realmName
            $params['metadataList'][0]['standardCredentials']['directoryDNSAddress'] = $realmDnsAddress
        }

        Write-Host "Updating $name"
        $result = api put -v2 data-protect/objects/metadata $metaParams
    }
}else{
    # report found instances
    $rdsNodes | Sort-Object -Property {$_.protectionSource.name} | Format-Table -Property @{label="Name"; expression={$_.protectionSource.name}}, @{label="Type"; expression={$_.protectionSource.awsProtectionSource.type}}, @{label="DB Engine"; expression={$_.protectionSource.awsProtectionSource.dbEngineId}}
    $rdsNodes | Sort-Object -Property {$_.protectionSource.name} | ForEach-Object{
        """{0}"",""{1}"",""{2}""" -f $_.protectionSource.name, $_.protectionSource.awsProtectionSource.type, $_.protectionSource.awsProtectionSource.dbEngineId | Out-File -FilePath $outfileName -Append
    }
}
