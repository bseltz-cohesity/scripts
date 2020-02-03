# usage:
# ./unprotectedGcpVms.ps1 -vip mycluster `
#                  -username myusername `
#                  -domain mydomain.net `
#                  -excludeProjects sbx, test `
#                  -policy 'My Policy' `
#                  -storageDomain DefaultStorageDomain `
#                  -sendTo myuser@mydomain.net, anotheruser@mydomain.net `
#                  -smtpServer 192.168.1.95 `
#                  -sendFrom backupreport@mydomain.net `
#                  -reprotectOldVms `
#                  -project myproject

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, # Cohesity user name
    [Parameter()][string]$domain = 'local', # Cohesity domain (local or AD domain)
    [Parameter()][array]$excludeProjects, # exclude projects with these substrings
    [Parameter(Mandatory = $True)][string]$policy, # policy to use for new jobs
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain', # name of storage domain
    [Parameter()][string]$smtpServer, # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, # outbound smtp port
    [Parameter()][array]$sendTo, # send to addresses
    [Parameter()][string]$sendFrom, # send from address
    [Parameter()][switch]$reprotectOldVMs, # protect all older (and new) unprotected VMs
    [Parameter()][string]$project = ''
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to Cohesity cluster
apiauth -vip $vip -username $username -domain $domain

# log file
$logFile = $(Join-Path -Path $PSScriptRoot -ChildPath log-autoProtectGcpVms.txt)
(Get-Content $logFile | Select-Object -Last 500) | Set-Content -Path $logFile

# get last seen ID file
$lastIdFile = $(Join-Path -Path $PSScriptRoot -ChildPath lastGcpId.txt)
if(Test-Path $lastIdFile){
    $lastId = (Get-Content $lastIdFile).ToString()
}else{
    $lastId = 0
}
if($reprotectOldVMs){
    $lastId = 0
}
$newLastId = 0

# find policy
$pol = api get protectionPolicies | Where-Object name -eq $policy
if(! $pol){
    Write-Host "Policy $policyName not found" -ForegroundColor Yellow
    exit
}

# find storage domain
$sd = api get viewBoxes | Where-Object name -eq $storageDomain
if(! $sd){
    write-host "Storage Domain $storageDomain not found" -ForegroundColor Yellow
    exit
}


# new job template
function createNewJob(){
    $thisJob = @{
        "createRemoteView"                 = $false;
        "fullProtectionSlaTimeMins"        = 120;
        "policyId"                         = $pol.id;
        "sourceIds"                        = @();
        "alertingPolicy"                   = @(
            "kFailure"
        );
        "viewBoxId"                        = $sd.id;
        "isActive"                         = $true;
        "indexingPolicy"                   = @{
            "disableIndexing" = $false;
            "denyPrefixes"    = @(
                "/`$Recycle.Bin";
                "/Windows";
                "/Program Files";
                "/Program Files (x86)";
                "/ProgramData";
                "/System Volume Information";
                "/Users/*/AppData";
                "/Recovery";
                "/var";
                "/usr";
                "/sys";
                "/proc";
                "/lib";
                "/grub";
                "/grub2"
            );
            "allowPrefixes"   = @(
                "/"
            );
            "cacheEnabled"    = $true
        };
        "priority"                         = "kMedium";
        "parentSourceId"                   = 0;
        "incrementalProtectionSlaTimeMins" = 60;
        "alertingConfig"                   = @{
            "emailDeliveryTargets" = @()
        };
        "qosType"                          = "kBackupHDD";
        "name"                             = "GCP Protection Job";
        "isDeleted"                        = $false;
        "startTime"                        = @{
            "hour"   = 21;
            "second" = 0;
            "minute" = 0
        };
        "timezone"                         = "America/New_York";
        "environment"                      = "kGCPNative";
    }
    return $thisJob
}


# cluster info
$cluster = api get cluster

# email message
$message = "Unprotected GCP VMs found on $($cluster.name):`n"
$vmsAdded = $false

# get GCP protection sources and jobs
$sources = api get protectionSources?environment=kGCP
$jobs = api get protectionJobs?environments=kGCPNative

foreach($source in $sources){
    $sourceName = $source.protectionSource.name

    # get list of protected VMs
    $protectedGcpVms = api get "protectionSources/protectedObjects?environment=kGCPNative&id=$($source.protectionSource.id)"
    $protectedIds = @($protectedGcpVms.protectionSource.id)

    # get list of projects
    $projects = $source.nodes | Where-Object {$_.protectionSource.gcpProtectionSource.type -eq 'kProject' -and $null -ne $_.nodes}
    foreach($proj in $projects){
        $projectName = $proj.protectionSource.name

        # skip project if name contains exclude strings or is not the specified project
        $skipProject = $false
        foreach($exclude in $excludeProjects){
            if($projectName -match $exclude){
                $skipProject = $True
            }
        }
        if($project -ne '' -and $projectName -ne $project){
            $skipProject = $True
        }

        if(! $skipProject){
            $jobChanged = $false
            $newJob = $false

            # find existing job or define a new job
            $job = $jobs | Where-Object name -eq "GCP-$projectName"
            if(! $job){
                $job = createNewJob
                $newJob = $True
                $job.name = "GCP-$projectName"
                $job.parentSourceId = $source.protectionSource.id
            }

            # get regions
            $regions = $proj.nodes
            foreach($region in $regions){
                $regionName = $region.protectionSource.name
    
                # get subnets
                $subnets = $region.nodes
                foreach($subnet in $subnets){
                    $subnetName = $subnet.protectionSource.name

                    # get vms
                    $vms = $subnet.nodes

                    foreach($vm in $vms){
                        $vmId = $vm.protectionSource.id
                        $vmName = $vm.protectionSource.name

                        # report new unprotected vm
                        if($vmId -notin $protectedIds -and $vmId -notin $job.sourceIds -and $vmId -gt $lastId){
                            # add vm to job 
                            $job.sourceIds += $vmId
                            $jobChanged = $True
                            $vmsAdded = $True
                            $newVMreport = "Adding {0}/{1}/{2}/{3}/{4} to {5}" -f $sourceName, $projectName, $regionName, $subnetName, $vmName, $job.name
                            "  $newVMreport"
                            $message += "    $newVMreport`n"
                            # update last seen ID
                            if($vmId -gt $newLastId){
                                $newLastId = $vmId
                            }
                        }
                    }
                }
            }
            if($jobChanged){
                # save job
                if($newJob){
                    $null = api post protectionJobs $job
                }else{
                    $null = api put protectionJobs/$($job.id) $job
                }
            }
        }
    }
}

if($vmsAdded){
    # update log file
    "$(get-date) --------------------------------------------------------------------" | Out-File -FilePath $logFile -Append
    $message | Out-File -FilePath $logFile -Append
    # send email report
    if($smtpServer -and $sendTo -and $sendFrom){
        write-host "`nsending report to $([string]::Join(", ", $sendTo))"
        foreach($toaddr in $sendTo){
            Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "New Unprotected GCP VMs ($($cluster.name))" -Body $message -WarningAction SilentlyContinue
        }
    }
    # update last seen ID file
    $newLastId | Out-File -FilePath $lastIdFile
}else{
    "  No new unprotected VMs discovered"
    # update log file
    "$(get-date) --------------------------------------------------------------------" | Out-File -FilePath $logFile -Append
    "  No new unprotected VMs discovered`n" | Out-File -FilePath $logFile -Append
}
