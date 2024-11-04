# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][array]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][array]$clusterName,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][switch]$transportErrorsOnly
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

function waitForRefresh($id){
    $authStatus = ""
    while($authStatus -ne 'Finished'){
        $rootFinished = $false
        $appsFinished = $false
        Start-Sleep 5
        $regInfo = api get "protectionSources/registrationInfo?ids=$id"
        if($regInfo.rootNodes){
            $rootNode = $regInfo.rootNodes[0]
        }else{
            $authStatus = 'Finished'
            break
        }        
        if($rootNode.registrationInfo.authenticationStatus -eq 'kFinished'){
            $rootFinished = $True
        }
        if($rootNode.registrationInfo.PSObject.Properties['registeredAppsInfo']){
            foreach($app in $rootNode.registrationInfo.registeredAppsInfo){
                if($app.authenticationStatus -eq 'kFinished'){
                    $appsFinished = $True
                    return $rootNode.rootNode.id
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
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

foreach($v in $vip){
    ### authenticate
    "`nConnecting to $v"
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -noPromptForPassword $noPrompt -mfaCode $mfaCode
    if(!$USING_HELIOS){
        ""
    }
    if($USING_HELIOS -and ! $clusterName){
        $clusterName = @((heliosClusters).name)
    }

    if(!$cohesity_api.authorized){
        Write-Host "$v Not authenticated" -ForegroundColor Yellow
    }else{
        if(!$USING_HELIOS){
            $clusterName = @((api get cluster).name)
        }
        foreach($cluster in $clusterName){
            if($USING_HELIOS){
                "`nConnecting to $cluster"
                $null = heliosCluster $cluster
            }
            # main
            $jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)
            $jobs = api get protectionJobs | Where-object {$_.isActive -ne $false -and $_.isDeleted -ne $True}

            if($jobNames.Count -gt 0){
                $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.name}
                if($notfoundJobs){
                    "Jobs not found $($notfoundJobs -join ', ')" | Tee-Object -FilePath $outfileName
                }
            }

            "Getting protection run status"
            foreach($job in $jobs | Sort-Object -Property name){
                $refreshSourceIds = @()
                $endUsecs = dateToUsecs (Get-Date)
                if(($jobNames.Count -eq 0 -and $job.isPaused -ne $True) -or $job.name -in $jobNames){
                    "    {0}" -f $job.name
                    $needsRun = $false

                    # check last run for aag state change
                    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=1"
                    $objectIds = @()
                    foreach($run in $runs){
                        $runStartTime = usecsToDate $run.backupRun.stats.startTimeUsecs
                        $status = $run.backupRun.status
                        $runType = $run.backupRun.runType
                        if($status -eq 'kFailure'){
                            if($run.backupRun.PSObject.Properties['error']){
                                $runNowParameters = @()
                                $message = $run.backupRun.error
                                $needsRun = $True
                                if($needsRun){
                                    "        ({0}): {1}" -f $runStartTime, $message
                                }
                                foreach($source in $run.backupRun.sourceBackupStatus){
                                    if($source.status -eq 'kFailure'){
                                        $sourceError = $source.error
                                        if($sourceError -match 'transport' -or ! $transportErrorsOnly){
                                            $sourceId = $source.source.id
                                            $refreshSourceIds = @($refreshSourceIds + $sourceId)
                                            $runNowParameter = @{
                                                "sourceId" = $sourceId;
                                            }
                                            $sourceName = $source.source.name
                                            foreach($app in $source.appsBackupStatus){
                                                if($app.PSObject.Properties['error']){
                                                    if(! $runNowParameter.databaseIds){
                                                        $runNowParameter.databaseIds = @()
                                                    }
                                                    $runNowParameter.databaseIds = @($runNowParameter.databaseIds + $app.appId)
                                                }
                                            }
                                            $runNowParameters = @($runNowParameters + $runNowParameter)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    # run incremental if needed
                    if($needsRun){
                        "        Refreshing sources..."
                        foreach($sourceId in $refreshSourceIds){
                            $result = api post "protectionSources/refresh/$sourceId"
                            $returnId = waitForRefresh($sourceId)
                        }
                        $jobId = $job.id
                        $policy = api get protectionPolicies | Where-Object {$_.id -eq $job.policyId}
                        # local retention from policy
                        $copyRunTargets = @()
                        # replicas from policy
                        if($policy.PSObject.Properties['snapshotReplicationCopyPolicies']){
                            foreach($replica in $policy.snapshotReplicationCopyPolicies){
                                if(!($copyRunTargets | Where-Object {$_.replicationTarget.clusterName -eq $replica.target.clusterName})){
                                    $copyRunTargets = @($copyRunTargets + @{
                                        "daysToKeep"        = $replica.daysToKeep;
                                        "replicationTarget" = $replica.target;
                                        "type"              = "kRemote"
                                    })
                                }
                            }
                        }
                        # archives from policy
                        if($policy.PSObject.Properties['snapshotArchivalCopyPolicies']){
                            foreach($archive in $policy.snapshotArchivalCopyPolicies){
                                if(!($copyRunTargets | Where-Object {$_.archivalTarget.vaultName -eq $archive.target.vaultName})){
                                    $copyRunTargets = @($copyRunTargets + @{
                                        "archivalTarget" = $archive.target;
                                        "daysToKeep"     = $archive.daysToKeep;
                                        "type"           = "kArchival"
                                    })
                                }
                            }
                        }
                        $runParams = @{
                            "runType" = $runType;
                            "usePolicyDefaults" = $True;
                            "copyRunTargets" = @($copyRunTargets);
                            "runNowParameters" = $runNowParameters;
                        }

                        $newRun = api post "protectionJobs/run/$jobId" $runParams
                        Write-Host "        Running job $($job.name) again..."
                    }
                }
            }
        }
    }
}
Write-Host "`nScript completed`n"
