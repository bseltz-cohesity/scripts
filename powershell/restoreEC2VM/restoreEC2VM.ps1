[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$instanceName,
    [Parameter()][string]$prefix = 'restore-',
    [Parameter()][switch]$powerOn,
    [Parameter()][switch]$originalLocation,
    [Parameter()][string]$awsSource = $null,
    [Parameter()][string]$region = $null,
    [Parameter()][string]$vpc = $null,
    [Parameter()][string]$keyPair = $null,
    [Parameter()][string]$subnet = $null,
    [Parameter()][string]$securityGroup = $null,
    [Parameter()][switch]$wait
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

if($powerOn){
    $powerState = $true
}else{
    $powerState = $false
}

# find requested VM
$search = api get "data-protect/search/protected-objects?snapshotActions=RecoverVMs,RecoverVApps,RecoverVAppTemplates&searchString=$instanceName&environments=kAWS" -v2

# latest snapshot
$snapshotId = $search.objects[0].latestSnapshotsInfo[0].localSnapshotInfo.snapshotId

if($originalLocation){
    # original location restore

    $recoveryParams = @{
        "name" = "Recover_AWS_VM_$instanceName";
        "snapshotEnvironment" = "kAWS";
        "awsParams" = @{
            "objects" = @(
                @{
                    "snapshotId" = $snapshotId
                }
            );
            "recoveryAction" = "RecoverVMs";
            "recoverVmParams" = @{
                "targetEnvironment" = "kAWS";
                "recoverProtectionGroupRunsParams" = @();
                "awsTargetParams" = @{
                    "renameRecoveredVmsParams" = @{
                        "prefix" = $prefix;
                        "suffix" = $null
                    };
                    "powerOnVms" = $powerState;
                    "continueOnError" = $null
                }
            }
        }
    }
}else{
    # alternate location restore

    if(!$awsSource){ Write-Host "-awsSource parameter required" -ForegroundColor Yellow; exit 1 }
    if(!$region){ Write-Host "-region parameter required" -ForegroundColor Yellow; exit 1 }
    if(!$vpc){ Write-Host "-vpc parameter required" -ForegroundColor Yellow; exit 1 }
    if(!$keyPair){ Write-Host "-keyPair parameter required" -ForegroundColor Yellow; exit 1 }
    if(!$subnet){ Write-Host "-subnet parameter required" -ForegroundColor Yellow; exit 1 }
    if(!$securityGroup){ Write-Host "-securityGroup parameter required" -ForegroundColor Yellow; exit 1 }

    # find requested protection source
    $myRootSource = api get "protectionSources/rootNodes?allUnderHierarchy=false&environments=kAWS" | where-object {$_.protectionSource.name -eq $awsSource}
    if(!$myRootSource){
        write-host "Protection Source $awsSource not found" -ForegroundColor Yellow
        exit 1
    }

    $thisSource = api get "protectionSources?id=$($myRootSource.protectionSource.id)"

    # find AWS region
    $thisRegion = $thisSource.nodes | Where-Object {$_.protectionSource.awsProtectionSource.type -eq 'kRegion' -and $_.protectionSource.name -eq $region}
    if(!$thisRegion){
        write-host "Region $region not found" -ForegroundColor Yellow
        exit 1
    }

    # find requested VPC
    $thisVPC = $thisRegion.nodes | Where-Object {$_.protectionSource.awsProtectionSource.type -eq 'kVPC' -and $_.protectionSource.name -eq $vpc}
    if(!$thisVPC){
        write-host "VPC $vpc not found" -ForegroundColor Yellow
        exit 1
    }

    # find requested keyPair
    $thisKeyPair = $thisRegion.nodes | Where-Object {$_.protectionSource.awsProtectionSource.type -eq 'kKeyPair' -and $_.protectionSource.name -eq $keyPair}
    if(!$thisKeyPair){
        write-host "KeyPair $keyPair not found" -ForegroundColor Yellow
        exit 1
    }

    # find request subnet
    $thisSubnet = $thisVPC.nodes | Where-Object {$_.protectionSource.awsProtectionSource.type -eq 'kSubnet' -and $_.protectionSource.name -eq $subnet}
    if(!$thisSubnet){
        write-host "Subnet $subnet not found" -ForegroundColor Yellow
        exit 1
    }

    # find requested security group
    $thisSecurityGroup = $thisVPC.nodes | Where-Object {$_.protectionSource.awsProtectionSource.type -eq 'kNetworkSecurityGroup' -and $_.protectionSource.name -eq $securityGroup}
    if(!$thisSecurityGroup){
        write-host "Security Group $securityGroup not found" -ForegroundColor Yellow
        exit 1
    }

    $recoveryParams = @{
        "name"                = "Recover_AWS_VM_$instanceName";
        "snapshotEnvironment" = "kAWS";
        "awsParams"           = @{
            "objects"         = @(
                @{
                    "snapshotId" = $snapshotId
                }
            );
            "recoveryAction"  = "RecoverVMs";
            "recoverVmParams" = @{
                "targetEnvironment"                = "kAWS";
                "recoverProtectionGroupRunsParams" = @();
                "awsTargetParams"                  = @{
                    "renameRecoveredVmsParams" = @{
                        "prefix" = $prefix;
                        "suffix" = $null
                    };
                    "recoveryTargetConfig"     = @{
                        "recoverToNewSource" = $true;
                        "newSourceConfig"    = @{
                            "source"        = @{
                                "id"   = $thisSource.protectionSource.id;
                                "name" = $thisSource.protectionSource.name
                            };
                            "region"        = @{
                                "id"   = $thisRegion.protectionSource.id;
                                "name" = $thisRegion.protectionSource.name
                            };
                            "keyPair"       = @{
                                "id"   = $thisKeyPair.protectionSource.id;
                                "name" = $thisKeyPair.protectionSource.name
                            };
                            "networkConfig" = @{
                                "securityGroups" = @(
                                    @{
                                        "id"   = $thisSecurityGroup.protectionSource.id;
                                        "name" = $thisSecurityGroup.protectionSource.name
                                    }
                                );
                                "subnet"         = @{
                                    "id"   = $thisSubnet.protectionSource.id;
                                    "name" = $thisSource.protectionSource.name
                                };
                                "vpc"            = @{
                                    "id"   = $thisVPC.protectionSource.id;
                                    "name" = $thisVPC.protectionSource.name
                                }
                            }
                        }
                    };
                    "powerOnVms"               = $powerState;
                    "continueOnError"          = $null
                }
            }
        }
    }
}

$result = api post "data-protect/recoveries" $recoveryParams -v2
$restoreTask = api get "data-protect/recoveries/$($result.id)" -v2
Write-Host "Restore is $($restoreTask.status)..."
if($wait){
    while($restoreTask.status -eq "Running"){
        Start-Sleep 30
        $restoreTask = api get "data-protect/recoveries/$($result.id)" -v2
    }
    Write-Host "Restore task $($restoreTask.status)"
}
