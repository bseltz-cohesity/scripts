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
    [Parameter(Mandatory=$True)][string]$ssoDomain,
    [Parameter()][array]$principalName,
    [Parameter()][string]$principalList,
    [Parameter()][array]$role,
    [Parameter()][switch]$remove,
    [Parameter()][switch]$generateApiKey,
    [Parameter()][switch]$group
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

$principalNames = @(gatherList -Param $principalName -FilePath $principalList -Name 'principals' -Required $True)

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

# get roles
$roles = api get "roles"
$myRoles = @()
foreach($roleName in $role){
    $thisRole = $roles | Where-Object {$_.name -eq $roleName -or $_.label -eq $roleName}
    if(!$thisRole){
        Write-Host "Role $roleName not found" -ForegroundColor Yellow
        exit 1
    }
    $myRoles = @($myRoles + $thisRole)
}

$users = api get "users"
$groups = api get "groups"

foreach($thisPrincipal in $principalNames){
    # find principal
    $existingUser = $users | Where-Object {$_.username -eq $thisPrincipal -and $_.domain -eq $ssoDomain}
    $existingGroup = $groups | Where-Object {$_.name -eq $thisPrincipal -and $_.domain -eq $ssoDomain}
    if(!$remove){
        if(!($existingUser -or $existingGroup)){
            if($role -eq $null -or $role.Count -eq 0){
                Write-Host "At least one role is required" -ForegroundColor Yellow
                exit 1
            }
            $newPrincipalParams = @(@{
                "principalName" = $thisPrincipal;
                "objectClass" = 'kUser'
                "roles" = @($myRoles.name);
                "domain" = $ssoDomain;
                "restricted" = $false
            })
            if($group){
                $newPrincipalParams[0]['objectClass'] = 'kGroup'
            }
            Write-Host "Adding $($ssoDomain)/$($thisPrincipal)"
            $existingUser = api post "idps/principals" $newPrincipalParams
        }else{
            Write-Host "$($ssoDomain)/$($thisPrincipal) already exists"
        }
        if($generateApiKey){
            if($existingUser){
                if($existingUser.PSObject.Properties['username']){
                    $keyName = $existingUser.username
                }else{
                    $keyName = $existingUser.principalName
                }
                $newKeyParams = @{
                    'isActive' = $True;
                    'user' = $existingUser;
                    'name' = "$($keyName)-$((dateToUsecs) / 1000000)"
                }
                $newKey = api post "users/$($existingUser.sid)/apiKeys/" $newKeyParams
                Write-Host "$($ssoDomain)/$($thisPrincipal) new API key: $($newKey.key)"
            }elseif($existingGroup){
                Write-Host "It's not possible to create an API key for a group" -ForegroundColor Yellow
                continue
            }
        }
    }else{
        if($existingUser){
            Write-Host "Removing $($ssoDomain)/$thisPrincipal"
            $deleteParams = @{
                "domain" = $ssoDomain;
                "users" = @(
                    $existingUser.username
                )
            }
            $null = api delete users $deleteParams
        }elseif($existingGroup){
            Write-Host "Removing $($ssoDomain)/$thisPrincipal"
            $deleteParams = @{
                "domain" = $ssoDomain;
                "names" = @(
                    $existingGroup.name
                )
            }
            $null = api delete groups $deleteParams
        }else{
            Write-Host "$($ssoDomain)/$thisPrincipal not found"
        }
    }
}
