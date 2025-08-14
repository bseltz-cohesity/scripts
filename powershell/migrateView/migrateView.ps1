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
    [Parameter()][string]$clusterName,
    [Parameter()][array]$viewName,
    [Parameter()][string]$viewList,
    [Parameter(Mandatory=$True)][string]$suffix,
    [Parameter()][string]$newStorageDomainName = 'DefaultStorageDomain',
    [Parameter()][switch]$finalize,
    [Parameter()][int64]$pageCount = 1000
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

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

$viewNames = @(gatherList -Param $viewName -FilePath $viewList -Name 'views' -Required $True)

$newStorageDomain = api get viewBoxes | Where-Object name -eq $newStorageDomainName
if(!$newStorageDomain){
    Write-Host "Storage Domain $newStorageDomainName not found" -ForegroundColor Yellow
    exit
}

foreach($viewName in $viewNames){
    $views = api get -v2 "file-services/views?viewNames=$viewName&includeProtectionGroups=true"
    $view = $views.views | Where-Object name -eq $viewName
    if(!$view){
        Write-Host "View $viewName not found" -foregroundcolor Yellow
        continue
    }
    $originalViewName = $view.name
    $originalViewId = $view.viewId
    if(!$finalize){
        ### create new view ###
        $newViewName = "$($view.name)-$suffix"
        $views = api get -v2 "file-services/views?viewNames=$newViewName&includeProtectionGroups=true"
        $thisNewView = $views.views | Where-Object name -eq $newViewName
        if(!$thisNewView){
            $newView = $view
            $newView.name = "$($view.name)-$suffix"
            $newView.storageDomainId = $newStorageDomain.id
            $newView.storageDomainName = $newStorageDomain.name
            Write-Host "- Creating new view $($newView.name)"
            $thisNewView = api post -v2 file-services/views $newView
        }else{
            Write-Host "- Found new view $($newView.name)"
        }
        
        foreach($alias in $view.aliases){
            $viewPath = $alias.viewPath.trimend("/")
            $null = api post viewAliases @{'viewName' = $thisNewView.name; 'viewPath' = $viewPath; 'aliasName' = "$($alias.aliasName)-$suffix"; 'sharePermissions' = $alias.sharePermissions}
        }
        ### protect new view ###
        if($view.PSObject.Properties['viewProtection'] -and $view.viewProtection.PSObject.Properties['protectionGroups'] -and $view.viewProtection.protectionGroups.Count -gt 0){
            $jobs = api get -v2 data-protect/protection-groups?environments=kView
            $job = $jobs.protectionGroups | Where-Object id -eq $view.viewProtection.protectionGroups[0].protectionGroupId
            $newJobName = "$($job.name)-$suffix"
            $newJob = $jobs.protectionGroups | Where-Object name -eq $newJobName
            if(! $newJob){
                Write-Host "- Creating protection group $newJobName"
                $newJob = $job
                $newJob.name = $newJobName
                $newJob.storageDomainId = $newStorageDomain.id
                $newJob.viewParams.objects = @(@{'id' = $thisNewView.viewId})
                if($newJob.viewParams.PSObject.Properties['replicationParams']){
                    foreach($viewNameConfig in $newJob.viewParams.replicationParams.viewNameConfigList){
                        if($viewNameConfig.sourceViewId -eq $view.viewId){
                            $viewNameConfig.sourceViewId = $thisNewView.viewId
                        }
                    }
                }
                $null = api post -v2 data-protect/protection-groups $newJob
            }else{
                if($thisNewView.viewId -notin @($newJob.viewParams.objects.id)){
                    Write-Host "- Adding new view to $($newJob.name)"
                    $newJob.viewParams.objects = @($newJob.viewParams.objects + @{'id' = $thisNewView.viewId})
                    if($newJob.viewParams.PSObject.Properties['replicationParams']){
                        $newJob.viewParams.replicationParams.viewNameConfigList = @($newJob.viewParams.replicationParams.viewNameConfigList + @{
                            'sourceViewId' = $thisNewView.viewId;
                            'useSameViewName' = $True
                        })
                    }
                    $null = api put -v2 data-protect/protection-groups/$($newJob.id) $newJob
                }
            }
        }
    }else{
        ### finalize ###
        $newViewName = "$($view.name)-$suffix"
        $views = api get -v2 file-services/views?viewNames=$newViewName
        $newView = $views.views | Where-Object name -eq $newViewName
        if(!$newView){
            Write-Host "* New View $newViewName not found" -foregroundcolor Yellow
            continue
        }
        $newViewId = $newView.viewId

        # copy directory quotas
        $cookie = $null
        while($True){
            if($cookie){
                $quotas = api get "viewDirectoryQuotas?viewName=$originalViewName&pageCount=$pageCount&cookie=$cookie"
            }else{
                $quotas = api get "viewDirectoryQuotas?viewName=$originalViewName&pageCount=$pageCount"
            }
            if(! $quotas.quotas){
                Write-Host "No quotas found"
            }

            foreach($quota in $quotas.quotas){
                if(!$quota.policy.PSObject.Properties['alertLimitBytes'] -or $quota.policy.alertLimitBytes -eq $null){
                    $alertLimitBytes = $quota.policy.hardLimitBytes * 0.9
                }else{
                    $alertLimitBytes = $quota.policy.alertLimitBytes
                }
                $quotaParams = @{
                    "viewName" = $newViewName;
                    "quota"    = @{
                        "dirPath" = $quota.dirPath;
                        "policy"  = @{
                            "hardLimitBytes"  = $quota.policy.hardLimitBytes;
                            "alertLimitBytes" = $alertLimitBytes
                        }
                    }
                }
                # put new quota
                Write-Host "- Setting directory quota on $($newViewName)$($quota.dirpath)..."
                $null = api put viewDirectoryQuotas $quotaParams
            }

            if($quotas.PSObject.Properties['cookie']){
                $cookie = $quotas.cookie
            }else{
                break
            }
        }

        # rename original view
        Write-Host "- Renaming view $($view.name) to $($view.name)-orig-$suffix"
        $view.name = "$($view.name)-orig-$suffix"
        $null = api put -v2 file-services/views/$($view.viewId) $view

        # rename original viewAliases
        foreach($alias in $view.aliases){
            $origAliasName = $alias.aliasName
            Write-Host "- Renaming alias $origAliasName to $($alias.aliasName)-orig-$suffix"
            $null = api delete viewAliases/$($origAliasName)
            $viewPath = $alias.viewPath.trimend("/")
            $newAliasName =  "$($alias.aliasName)-orig-$suffix"
            $null = api post viewAliases @{'viewName' = $view.name; 'viewPath' = $viewPath; 'aliasName' = "$($newAliasName)"; 'sharePermissions' = $alias.sharePermissions}
        }
            
        # rename new view
        Write-Host "- Renaming view $($newView.name) to $originalViewName"
        $newView.name = $originalViewName
        $null = api put -v2 file-services/views/$($newViewId) $newView

        # rename new viewAliases
        foreach($alias in $newView.aliases){
            $origAliasName = $alias.aliasName -replace "-$suffix", ""
            $null = api delete viewAliases/$($alias.aliasName)
            $viewPath = $alias.viewPath.trimend("/")
            Write-Host "- Renaming new alias $($alias.aliasName) to $origAliasName"
            $null = api post viewAliases @{'viewName' = $newView.name; 'viewPath' = $viewPath; 'aliasName' = "$($origAliasName)"; 'sharePermissions' = $alias.sharePermissions}
        }
    }
}
