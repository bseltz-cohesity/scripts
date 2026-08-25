# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
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
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][switch]$listRuns,
    [Parameter()][string]$runId,
    [Parameter()][switch]$removeHold,
    [Parameter()][switch]$addHold,
    [Parameter()][switch]$latest,
    [Parameter()][datetime]$startDate,
    [Parameter()][datetime]$endDate,
    [Parameter()][int64]$vaultId,
    [Parameter()][string]$vaultName,
    [Parameter()][int]$numRuns = 1000
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

function Get-RunStartTimeUsecs($run) {
    if($run.localBackupInfo -and $run.localBackupInfo.startTimeUsecs) {
        return [int64]$run.localBackupInfo.startTimeUsecs
    }

    if($run.id -and ([string]$run.id).Contains(':')) {
        return [int64](([string]$run.id).Split(':')[-1])
    }

    return 0
}

function Get-FortKnoxTargets($run) {
    $targets = @($run.archivalInfo.archivalTargetResults)
    return @($targets | Where-Object {
        $ownershipContext = [string]$_.ownershipContext
        $usageType = [string]$_.usageType
        $ownershipContext -in @('FortKnox', 'kOwnershipContextFortKnox') -or
            $usageType -in @('Rpaas', 'RPaaS', 'kRpaas', 'kRPaaS')
    })
}

function Get-RunId($run, $job) {
    if($run.id) {
        return [string]$run.id
    }

    return "$($job.id):$(Get-RunStartTimeUsecs $run)"
}

function Get-FortKnoxRunEntries($runs, $job) {
    $entries = @()
    foreach($run in $runs) {
        $runStartTimeUsecs = Get-RunStartTimeUsecs $run
        foreach($target in (Get-FortKnoxTargets $run)) {
            $entries += [PSCustomObject]@{
                Run = $run
                RunId = Get-RunId $run $job
                RunStartTimeUsecs = $runStartTimeUsecs
                RunDate = if($runStartTimeUsecs) { usecsToDate $runStartTimeUsecs } else { $null }
                VaultId = [int64]$target.targetId
                VaultName = [string]$target.targetName
                Status = [string]$target.status
                OnLegalHold = [bool]$target.onLegalHold
                ExpiryTimeUsecs = if($target.expiryTimeUsecs) { [int64]$target.expiryTimeUsecs } else { 0 }
                ExpiryDate = if($target.expiryTimeUsecs) { usecsToDate ([int64]$target.expiryTimeUsecs) } else { $null }
                Target = $target
            }
        }
    }
    return @($entries)
}

function Stop-WithMessage([string]$message) {
    Write-Host $message -ForegroundColor Yellow
    exit 1
}

if($addHold -and $removeHold) {
    Stop-WithMessage 'Specify only one of -addHold or -removeHold.'
}

if(($startDate -and !$endDate) -or ($endDate -and !$startDate)) {
    Stop-WithMessage 'Specify both -startDate and -endDate.'
}

if(($latest -and $runId) -or ($latest -and $startDate) -or ($runId -and $startDate)) {
    Stop-WithMessage 'Use only one run selector: -latest, -runId, or a date range.'
}

if($numRuns -lt 1) {
    Stop-WithMessage '-numRuns must be greater than zero.'
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password `
    -apiKeyAuthentication $useApiKey -mfaCode $mfaCode `
    -sendMfaCode $emailMfaCode -heliosAuthentication $mcm `
    -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region) {
    if($clusterName) {
        $thisCluster = heliosCluster $clusterName
    } else {
        Stop-WithMessage 'Please provide -clusterName when connecting through Helios or MCM.'
    }
}

if(!$cohesity_api.authorized) {
    Stop-WithMessage 'Not authenticated.'
}

$jobResponse = api get -v2 'data-protect/protection-groups?isDeleted=false&includeTenants=true'
if($null -eq $jobResponse) {
    Stop-WithMessage "Unable to list protection groups: $($cohesity_api.last_api_error)"
}

$jobs = @($jobResponse.protectionGroups | Where-Object { $_.name -ieq $jobName })

if($jobs.Count -eq 0) {
    Stop-WithMessage "Protection group '$jobName' not found."
}

if($jobs.Count -gt 1) {
    Stop-WithMessage "More than one protection group named '$jobName' was found. Select the cluster first or use a unique name."
}

$job = $jobs[0]
$runsResponse = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&includeObjectDetails=false&includeTenants=true&excludeNonRestorableRuns=true"
if($null -eq $runsResponse) {
    Stop-WithMessage "Unable to list runs for '$jobName': $($cohesity_api.last_api_error)"
}

$entries = @(Get-FortKnoxRunEntries @($runsResponse.runs) $job)

if($vaultId) {
    $entries = @($entries | Where-Object { $_.VaultId -eq $vaultId })
}

if($vaultName) {
    $entries = @($entries | Where-Object { $_.VaultName -ieq $vaultName })
}

if($listRuns) {
    if($entries.Count -eq 0) {
        Stop-WithMessage "No FortKnox vaulted copies were found for protection group '$jobName'."
    }

    $entries |
        Sort-Object -Property RunStartTimeUsecs -Descending |
        Select-Object RunId, RunDate, VaultId, VaultName, Status, OnLegalHold, ExpiryDate |
        Format-Table -AutoSize
    exit 0
}

if($runId) {
    $entries = @($entries | Where-Object { $_.RunId -eq $runId })
} elseif($latest) {
    $latestStartTimeUsecs = ($entries | Measure-Object -Property RunStartTimeUsecs -Maximum).Maximum
    $entries = @($entries | Where-Object { $_.RunStartTimeUsecs -eq $latestStartTimeUsecs })
} elseif($startDate -and $endDate) {
    $startTimeUsecs = dateToUsecs $startDate.Date
    $endTimeUsecs = dateToUsecs ($endDate.Date.AddDays(1).AddTicks(-1))
    $entries = @($entries | Where-Object {
        $_.RunStartTimeUsecs -ge $startTimeUsecs -and $_.RunStartTimeUsecs -le $endTimeUsecs
    })
} else {
    Stop-WithMessage 'Specify -listRuns, -latest, -runId, or both -startDate and -endDate.'
}

if($entries.Count -eq 0) {
    Stop-WithMessage 'No matching FortKnox vaulted copies were found.'
}

if(!$addHold -and !$removeHold) {
    $entries |
        Sort-Object -Property RunStartTimeUsecs -Descending |
        Select-Object RunId, RunDate, VaultId, VaultName, Status, OnLegalHold, ExpiryDate |
        Format-Table -AutoSize
    exit 0
}

$holdValue = [bool]$addHold
$nowUsecs = [int64](dateToUsecs)
$failures = 0

foreach($entry in $entries) {
    if($entry.OnLegalHold -eq $holdValue) {
        Write-Host "$($entry.RunId) / $($entry.VaultName): legal hold is already $holdValue; skipping."
        continue
    }

    if($addHold -and $entry.ExpiryTimeUsecs -gt 0 -and $entry.ExpiryTimeUsecs -le $nowUsecs) {
        Write-Host "$($entry.RunId) / $($entry.VaultName): vaulted copy is expired; legal hold cannot be added." -ForegroundColor Yellow
        $failures += 1
        continue
    }

    if($removeHold -and $entry.ExpiryTimeUsecs -gt 0 -and $entry.ExpiryTimeUsecs -le $nowUsecs) {
        Write-Host "$($entry.RunId) / $($entry.VaultName): warning: removing legal hold may make this copy immediately eligible for expiration." -ForegroundColor Yellow
    }

    $request = @{
        'updateProtectionGroupRunParams' = @(
            @{
                'runId' = $entry.RunId
                'archivalSnapshotConfig' = @{
                    'updateExistingSnapshotConfig' = @(
                        @{
                            'id' = $entry.VaultId
                            'name' = $entry.VaultName
                            'archivalTargetType' = 'Cloud'
                            'enableLegalHold' = $holdValue
                        }
                    )
                }
            }
        )
    }

    $action = if($holdValue) { 'Adding' } else { 'Removing' }
    Write-Host "$action legal hold: $($entry.RunId) / $($entry.VaultName)..."
    $result = api put -v2 "data-protect/protection-groups/$($job.id)/runs" $request

    $failedRuns = @($result.failedRuns)
    if($null -eq $result -or $failedRuns.Count -gt 0) {
        $errorMessage = if($failedRuns.Count -gt 0) {
            ($failedRuns.errorMessage | Where-Object { $_ }) -join '; '
        } else {
            $cohesity_api.last_api_error
        }
        Write-Host "Failed: $errorMessage" -ForegroundColor Yellow
        $failures += 1
    } else {
        Write-Host "Success: legal hold is now $holdValue on $($entry.VaultName)."
    }
}

if($failures -gt 0) {
    Write-Host "$failures FortKnox legal hold update(s) failed." -ForegroundColor Yellow
    exit 1
}
