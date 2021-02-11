# usage:
# ./archiveAndExtend.ps1 -vip mycluster `
#                        -username myuser `
#                        -domain mydomain.net `
#                        -policyNames 'my policy', 'another policy' `
#                        -archiveDaily 14 `
#                        -dailyVault myDailyTarget `
#                        -keepWeekly 14 `
#                        -archiveWeekly 30 `
#                        -weeklyVault myWeeklyTarget `
#                        -dayOfWeek Sunday `
#                        -keepMonthly 90 `
#                        -archiveMonthly 180 `
#                        -monthlyVault myMonthlyTarget `
#                        -dayOfMonth 1 `
#                        -keepQuarterly 365 `
#                        -archiveQuarterly 2555 `
#                        -quarterlyVault myQuarterlyTarget `
#                        -quarterlyDates '04-01', '07-01' `
#                        -keepYearly 180 `
#                        -archiveYearly 365 `
#                        -yearlyVault myYearlyTarget `
#                        -dayOfYear -1 `
#                        -keepSpecial 365 `
#                        -archiveSpecial 2555 `
#                        -specialVault mySpecialTarget `
#                        -specialDates '03-21', '09-21 `
#                        -commit

# process commandline arguments
[CmdletBinding()]
param (
    # main params
    [Parameter(Mandatory = $True)][string]$vip, # cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][array]$policyNames, # jobs to archive
    [Parameter()][int32]$newerThan = 5, # don't process spanshots older than X days
    [Parameter()][switch]$commit, # if excluded script will run in test run mode and will not archive
    # daily params
    [Parameter()][int32]$archiveDaily = 0, # archive retention for daily snapshots
    [Parameter()][string]$dailyVault = $null, # name of daily archive target
    # weekly params
    [Parameter()][int32]$keepWeekly = 0, # local retention (days) for weekly snapshots
    [Parameter()][int32]$archiveWeekly = 0, # archive retention for weekly snapshots
    [Parameter()][string]$weeklyVault = $null, # name of weekly archive target
    [Parameter()][ValidateSet('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','unselected')][string]$dayOfWeek = 'unselected',
    [Parameter()][int32]$maxWeeklyDrift = 2, # if day was missed how many days late will we use
    # monthly params
    [Parameter()][int32]$keepMonthly = 0, # local retention (days) for monthly snapshots
    [Parameter()][int32]$archiveMonthly = 0, # archive retention for monthly snapshots
    [Parameter()][string]$monthlyVault = $null, # name of monthly archive target
    [Parameter()][ValidateRange(-1,31)][int32]$dayOfMonth = 0,
    [Parameter()][int32]$maxMonthlyDrift = 4, # if day was missed how many days late will we use
    # quarterly params
    [Parameter()][int32]$keepQuarterly = 0, # local retention (days) for quarterly snapshots
    [Parameter()][int32]$archiveQuarterly = 0, # archive retention for quarterly snapshots
    [Parameter()][string]$quarterlyVault = $null, # name of quarterly archive target
    [Parameter()][array]$quarterlyDates = $null, # days to run quarterlies
    [Parameter()][int32]$maxQuarterlyDrift = 4, # if day was missed how many days late will we use
    # yearly params
    [Parameter()][int32]$keepYearly = 0, # local retention (days) for yearly snapshots
    [Parameter()][int32]$archiveYearly = 0, # archive retention for yearly snapshots
    [Parameter()][string]$yearlyVault = $null, # name of yearly archive target
    [Parameter()][ValidateRange(-1,366)][int32]$dayOfYear = 0,
    [Parameter()][int32]$maxYearlyDrift = 4, # if day was missed how many days late will we use
    # special params
    [Parameter()][int32]$keepSpecial = 0, # local retention (days) for yearly snapshots
    [Parameter()][int32]$archiveSpecial = 0, # archive retention for yearly snapshots
    [Parameter()][string]$specialVault = $null, # name of special archive target
    [Parameter()][array]$specialDates = $null, # name of archive target
    [Parameter()][int32]$maxSpecialDrift = 4 # if day was missed how many days late will we use
)

# validate daily parameters

if($archiveDaily -ne 0){
    if('' -eq $dailyVault){
        Write-Host "-dailyVault required" -ForegroundColor Yellow
        exit
    }
}

# validate weekly parameters

if($keepWeekly -ne 0){
    if($dayOfWeek -eq 'unselected'){
        write-host "-dayOfWeek required" -ForegroundColor Yellow
        exit
    }
}

if($archiveWeekly -ne 0){
    if($dayOfWeek -eq 'unselected'){
        write-host "-dayOfWeek required" -ForegroundColor Yellow
        exit
    }
    if('' -eq $weeklyVault){
        write-host "-weeklyVault required" -ForegroundColor Yellow
        exit
    }
}

# validate monthly parameters

if($keepMonthly -ne 0 -and $dayOfMonth -eq 0){
    write-host "-dayOfMonth required" -ForegroundColor Yellow
    exit
}

if($archiveMonthly -ne 0){
    if($dayOfMonth -eq 0){
        write-host "-dayOfMonth required" -ForegroundColor Yellow
        exit
    }
    if('' -eq $monthlyVault){
        write-host "-monthlyVault required" -ForegroundColor Yellow
        exit
    }
}

# validate quarterly parameters

if($keepQuarterly -ne 0 -and $quarterlyDates.Length -eq 0){
    write-host "-quarterlyDates required" -ForegroundColor Yellow
    exit
}

if($archiveQuarterly -ne 0){
    if($quarterlyDates.Length -eq 0){
        write-host "-quarterlyDates required" -ForegroundColor Yellow
        exit
    }
    if('' -eq $quarterlyVault){
        write-host "-quarterlyVault required" -ForegroundColor Yellow
        exit
    }
}

# validate yearly parameters

if($keepYearly -ne 0 -and $dayOfYear -eq 0){
    write-host "-dayOfYear required" -ForegroundColor Yellow
    exit
}

if($archiveYearly -ne 0){
    if($dayOfYear -eq 0){
        write-host "-dayOfYear required" -ForegroundColor Yellow
        exit
    }
    if('' -eq $yearlyVault){
        write-host "-yearlyVault required" -ForegroundColor Yellow
        exit
    }
}

# validate special parameters

if($keepSpecial -ne 0 -and $specialDates.Length -eq 0){
        write-host "-specialDates required" -ForegroundColor Yellow
        exit
}

if($archiveSpecial -ne 0){
    if($specialDates.Length -eq 0){
        write-host "-specialDates required" -ForegroundColor Yellow
        exit
    }
    if('' -eq $specialVault){
        write-host "-specialVault required" -ForegroundColor Yellow
        exit
    }
}

# number of days per month
$monthDays = @(0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)

# start logging
$logfile = $(Join-Path -Path $PSScriptRoot -ChildPath log-archiveAndExtend.txt)
"`nScript Run: $(Get-Date)" | Out-File -FilePath $logfile -Append

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get archive target info
$vaults = api get vaults

if($dailyVault){
    $dVault = $vaults | Where-Object { $_.name -eq $dailyVault }
    if(!$dVault){
        "  Archive Target $dailyVault not found" | Tee-Object -FilePath $logfile -Append | Write-Host -ForegroundColor Yellow
        exit        
    }
}

if($weeklyVault){
    $wVault = $vaults | Where-Object { $_.name -eq $weeklyVault }
    if(!$wVault){
        "  Archive Target $weeklyVault not found" | Tee-Object -FilePath $logfile -Append | Write-Host -ForegroundColor Yellow
        exit
    }
}

if($monthlyVault){
    $mVault = $vaults | Where-Object { $_.name -eq $monthlyVault }
    if(!$mVault){
        "  Archive Target $monthlyVault not found" | Tee-Object -FilePath $logfile -Append | Write-Host -ForegroundColor Yellow
        exit
    }
}

if($quarterlyVault){
    $qVault = $vaults | Where-Object { $_.name -eq $monthlyVault }
    if(!$qVault){
        "  Archive Target $quarterlyVault not found" | Tee-Object -FilePath $logfile -Append | Write-Host -ForegroundColor Yellow
        exit
    }
}

if($yearlyVault){
    $yVault = $vaults | Where-Object { $_.name -eq $yearlyVault }
    if(!$yVault){
        "  Archive Target $yearlyVault not found" | Tee-Object -FilePath $logfile -Append | Write-Host -ForegroundColor Yellow
        exit        
    }
}

if($specialVault){
    $sVault = $vaults | Where-Object { $_.name -eq $specialVault }
    if(!$sVault){
        "  Archive Target $specialVault not found" | Tee-Object -FilePath $logfile -Append | Write-Host -ForegroundColor Yellow
        exit        
    }
}

# job selector
$jobs = api get protectionJobs | Where-Object {$_.isDeleted -ne $True}
$policies = api get protectionPolicies
$selectedJobs = @()
$global:processedArchives = @()
$global:processedExtensions = @()

foreach($policyName in $policyNames){
    $policy = $policies | Where-Object name -eq $policyname
    if($policy){
        $policyJobs = $jobs | Where-Object policyId -eq $policy.id
        $selectedJobs += $policyJobs
    }else{
        # report policy not found
        "  $($policyName): Policy not found" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Yellow
    }
}

function extendAndArchiveSnapshot($run, $keepDays, $archiveDays, $extendType){

    $editRun = $false

    $startTimeUsecs = $run.copyRun[0].runStartTimeUsecs
    $runDate = usecsToDate $startTimeUsecs

    $runParameters = @{
        "jobRuns"= @(
            @{
                "jobUid" = $run.jobUid;
                "runStartTimeUsecs" = $startTimeUsecs;
                "copyRunTargets" = @()
            }
        )
    }

    # calculate days to extend snapshot
    $currentExpireTimeUsecs = $run.copyRun[0].expiryTimeUsecs
    $newExpireTimeUsecs = $startTimeUsecs + ($keepDays * 86400000000)
    $newExpireDate = (usecsToDate $newExpireTimeUsecs).ToString('yyyy-MM-dd')
    $daysToExtend = [math]::Round(($newExpireTimeUsecs - $currentExpireTimeUsecs) / 86400000000)
    # ignore daily local retention (already set by policy)
    if($extendType -eq 'daily'){
        $daysToExtend = 0
    }
    if($keepDays -ne 0){
        if("$($runDate.Year)-$($runDate.DayOfYear)-$($run.jobId)" -notin $global:processedExtensions){
            if($daysToExtend -gt 0){
                $runParameters.jobRuns[0].copyRunTargets += @{
                    "daysToKeep" = [int] $daysToExtend;
                    "type" = "kLocal"
                }
                if($commit){
                    "  $runDate - extending to $newExpireDate ($extendType)" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
                    $editRun = $True
                }else{
                    "  $runDate - would extend to $newExpireDate ($extendType)" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
                }  
            }else{
                if($extendType -ne 'daily'){
                    "  $runDate - already extended to $newExpireDate ($extendType)" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
                }
            }
            $global:processedExtensions += "$($runDate.Year)-$($runDate.DayOfYear)-$($run.jobId)"
        }
    }

    if($archiveDays -gt 0){
        # select vault
        if($extendType -eq 'yearly'){
            $vault = $yVault
        }elseif($extendType -eq 'quarterly'){
            $vault = $qVault
        }elseif($extendType -eq 'monthly'){
            $vault = $mVault
        }elseif($extendType -eq 'weekly'){
            $vault = $wVault
        }elseif($extendType -eq 'special'){
            $vault = $sVault
        }elseif($extendType -eq 'daily'){
            $vault = $dVault
        }

        $vaultId = $vault.id
        $vaultName = $vault.name

        # calculate days to keep archive
        $expireTimeUsecs = $startTimeUsecs + ([int]$archiveDays * 86400000000)

        # find existing archive date
        $existingExpiry = 0
        foreach($copyRun in $run.copyRun){
            if($copyRun.target.type -eq 'kArchival' -and $copyRun.target.archivalTarget.vaultId -eq $vaultId){
                $existingExpiry = $copyRun.expiryTimeUsecs
                $existingExpiryDate = usecsToDate $existingExpiry
            }
        }
        if($existingExpiry -eq 0){
            # new archive
            $now = dateToUsecs $(get-date)
            $daysToKeep = [math]::Round(($expireTimeUsecs - $now) / 86400000000)
            $expireDate = (get-date).AddDays($daysToKeep).ToString('yyyy-MM-dd')
        }else{
            # extend existing archive
            $daysToKeep = [math]::Round(($expireTimeUsecs - $existingExpiry) / 86400000000)
            $expireDate = $existingExpiryDate.AddDays($daysToKeep).ToString('yyyy-MM-dd')
        }

        if("$($runDate.Year)-$($runDate.DayOfYear)-$($run.jobId)" -notin $global:processedArchives){
            if($daysToKeep -gt 0){
                $runParameters.jobRuns[0].copyRunTargets += @{
                    'archivalTarget' = @{
                        'vaultId'   = $vaultId;
                        'vaultName' = $vaultName;
                        'vaultType' = 'kCloud'
                    };
                    'daysToKeep'     = [int] $daysToKeep;
                    'type'           = 'kArchival'
                }
                if ($commit) {
                    # archive the snapshot
                    "  $runDate - archiving to $expireDate ($extendType)" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
                    $editRun = $True
                }else{
                    # display only (test run)
                    "  $runDate - would archive to $expireDate ($extendType)" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
                }
            }else{
                if($existingExpiry -ne 0){
                    "  $runDate - already archived to $expireDate ($extendType)" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
                }
            }
            $global:processedArchives += "$($runDate.Year)-$($runDate.DayOfYear)-$($run.jobId)"
        }
    }

    # commit any changes
    if($editRun -eq $True){
        $null = api put protectionRuns $runParameters
    }
}

# calculate dates to process
$wantedDays = @()
$x = $newerThan
while($x -gt 0){
    $thisDate = (get-date).AddDays(-$x)
    # handle leapyear for end of year
    $selectedDayOfYear = $dayOfYear
    if($dayOfYear -eq -1){
        $selectedDayOfYear = 365
        if([datetime]::IsLeapYear($thisDate.Year)){
            $selectedDayOfYear = 366
        }
    }

    # handle leapyear for end of February
    $selectedDayOfMonth = $dayOfMonth
    if($dayOfMonth -eq -1){
        $selectedDayOfMonth = $monthDays[$thisDate.Month]
        if($runDate.Month -eq 2 -and [datetime]::IsLeapYear($thisDate.Year)){
            $selectedDayOfMonth += 1
        }
    }

    # assign date to correct target
    if("{0:00}-{1:00}" -f $thisDate.Month, $thisDate.Day -in $specialDates){
        $wantedDays += "$($thisDate.ToString('yyyy-MM-dd')):special"
    }elseif($thisDate.DayOfYear -eq $selectedDayOfYear){
        $wantedDays += "$($thisDate.ToString('yyyy-MM-dd')):yearly"
    }elseif("{0:00}-{1:00}" -f $thisDate.Month, $thisDate.Day -in $quarterlyDates){
        $wantedDays += "$($thisDate.ToString('yyyy-MM-dd')):quarterly"
    }elseif($thisDate.Day -eq $selectedDayOfMonth){
        $wantedDays += "$($thisDate.ToString('yyyy-MM-dd')):monthly"
    }elseif($thisDate.DayOfWeek -eq $dayOfWeek){
        $wantedDays += "$($thisDate.ToString('yyyy-MM-dd')):weekly"
    }elseif($archiveDaily -ne 0){
        $wantedDays += "$($thisDate.ToString('yyyy-MM-dd')):daily"
    }
    $x -= 1
}

# find job runs that match dates to process
foreach($job in $selectedJobs){
    "$($job.name)" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor White

    $runs = api get "protectionRuns?jobId=$($job.id)&runTypes=kRegular&runTypes=kFull&excludeTasks=true&excludeNonRestoreableRuns=true&startTimeUsecs=$(timeAgo ($newerThan + 2) days)" | `
        Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
        Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

    $runCount = 0
    foreach($wantedDay in $wantedDays){
        $dateString, $extendType = $wantedDay.split(':')
        $wantedUsecs = dateToUsecs $dateString
        $wantedDate = usecsToDate $wantedUsecs
        $wantedRuns = $runs | Where-Object { $_.copyRun[0].runStartTimeUsecs -ge $wantedUsecs } | `
            Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }
        $dailyRuns = $wantedRuns | Group-Object -Property {(usecsToDate $_.copyRun[0].runStartTimeUsecs).DayOfYear}, {(usecsToDate $_.copyRun[0].runStartTimeUsecs).Year}
        if($dailyRuns){
            $theseRuns = $dailyRuns[0].Group | Sort-Object -Property { $_.copyRun[0].runStartTimeUsecs } -Descending
            $run = $theseruns[0]
            $runDate = usecsToDate ($run.copyRun[0].runStartTimeUsecs)
            # process archive/extension
            if($extendType -eq 'special' -and $runDate -le $wantedDate.AddDays($maxSpecialDrift)){
                extendAndArchiveSnapshot $run $keepSpecial $archiveSpecial $extendType
            }elseif($extendType -eq 'yearly' -and $runDate -le $wantedDate.AddDays($maxYearlyDrift)){
                extendAndArchiveSnapshot $run $keepYearly $archiveYearly $extendType
            }elseif($extendType -eq 'quarterly' -and $runDate -le $wantedDate.AddDays($maxQuarterlyDrift)){
                extendAndArchiveSnapshot $run $keepQuarterly $archiveQuarterly $extendType
            }elseif($extendType -eq 'monthly' -and $runDate -le $wantedDate.AddDays($maxMonthlyDrift)){
                extendAndArchiveSnapshot $run $keepMonthly $archiveMonthly $extendType
            }elseif($extendType -eq 'weekly' -and $runDate -le $wantedDate.AddDays($maxWeeklyDrift)){
                extendAndArchiveSnapshot $run $keepWeekly $archiveWeekly $extendType
            }elseif($extendType -eq 'daily' -and $runDate.DayOfYear -eq $wantedDate.DayOfYear){
                extendAndArchiveSnapshot $run 0 $archiveDaily $extendType
            }
            $runCount += 1
        }
    }
    if($runCount -eq 0){
        "  No runs meet criteria" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Yellow
    }
}
