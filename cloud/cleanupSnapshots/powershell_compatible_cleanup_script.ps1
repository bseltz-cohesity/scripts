# Copyright 2024 Cohesity Inc.
#
# Author: Kanak Agarwal
#
# Script to cleanup azure snapshots using powershell.
#

# Logging functions for INFO and ERROR messages
function log_info {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] INFO: $message" -ForegroundColor Blue
}

function log_error {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] ERROR: $message" -ForegroundColor Red
}

# Prompt the user to input the Application ID
$appId = Read-Host -Prompt "Enter Application ID"

# Prompt the user to input the Service Principal Key
$servicePrincipalKey = Read-Host -Prompt "Enter Service Principal Key" -AsSecureString

# Prompt the user to input the Tenant ID
$tenantId = Read-Host -Prompt "Enter Tenant ID"

# Log the login action
log_info "Logging in with service principal"

# Create credential object
$cred = New-Object System.Management.Automation.PSCredential ($appId, $servicePrincipalKey)


# Login with service principal
try {
    Connect-AzAccount -ServicePrincipal -TenantId $tenantId -Credential $cred -ErrorAction Stop
    log_info "Azure login successful"
}
catch {
    log_error "Azure login failed: $($_.Exception.Message)"
    exit 1
}

# Prompt the user for the number of days
[int]$n = Read-Host -Prompt "Enter the number of days for snapshots to be older than"

# Prompt the user for the Job ID (optional)
$jobId = Read-Host -Prompt "Enter Job ID (optional)"

# Get the current date in seconds since epoch
$currentDate = [DateTimeOffset]::Now.ToUnixTimeSeconds()

# Calculate the threshold date in seconds since epoch
$thresholdDate = $currentDate - ($n * 86400)  # 86400 seconds in a day

log_info "Threshold date calculated as $([DateTimeOffset]::FromUnixTimeSeconds($thresholdDate))"

# Get the list of snapshots based on the presence of the Job ID
if (-not [string]::IsNullOrEmpty($jobId)) {
    log_info "Fetching snapshots with 'cohesity-tag' and Job ID: $jobId"
    $snapshots = Get-AzSnapshot | Where-Object {
        $_.Tags['cohesity-tag'] -ne $null -and $_.TimeCreated -ne $null -and $_.Tags['cohesity-tag'] -like "*${jobId}*"
    } | Select-Object -Property Id, TimeCreated
} else {
    log_info "Fetching all snapshots with 'cohesity-tag'"
    $snapshots = Get-AzSnapshot | Where-Object {
        $_.Tags['cohesity-tag'] -ne $null -and $_.TimeCreated -ne $null
    } | Select-Object -Property Id, TimeCreated
}

# Initialize an array to store IDs of snapshots to delete
$snapshotsToDelete = @()

# Loop through each snapshot
foreach ($snapshot in $snapshots) {
    # Convert creation time to seconds since epoch
    $creationDate = [DateTimeOffset]::Parse($snapshot.TimeCreated).ToUnixTimeSeconds()

    # Check if the creation time is older than the threshold
    if ($creationDate -lt $thresholdDate) {
        log_info "Snapshot $($snapshot.Id) was created on $($snapshot.TimeCreated)"
        # Add the snapshot ID to the array for deletion
        $snapshotsToDelete += $snapshot.Id
    }
}

# Check if there are snapshots to delete
if ($snapshotsToDelete.Count -gt 0) {
    log_info "Found $($snapshotsToDelete.Count) snapshots to delete"
    # Prompt for confirmation
    $confirmation = Read-Host -Prompt "Do you want to delete the listed snapshots? Type YES to confirm"
    if ($confirmation -eq "YES") {
        log_info "Deleting Snapshots:"
        foreach ($snapshotId in $snapshotsToDelete) {
            log_info "$snapshotId"
        }
        # Delete the snapshots
        foreach ($snapshotId in $snapshotsToDelete) {
          try {
            Remove-AzResource -ResourceId $snapshotId -Force -ErrorAction Stop
            log_info "Deleted snapshot $snapshotId"
          }
          catch {
            log_error "Failed to delete $snapshotId : $($_.Exception.Message)"
          }
        }
        log_info "All Snapshots deleted successfully."
    } else {
        log_info "Deletion cancelled. No snapshots were deleted."
    }
} else {
    log_info "No snapshots to delete."
}
