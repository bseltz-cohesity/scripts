#!/bin/bash
#
# Copyright 2024 Cohesity Inc.
#
# Author: Kanak Agarwal
#
# Script to cleanup azure snapshots using bash on azure cloud shell.
#

# Logging functions for INFO and ERROR messages
log_info() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\033[34m[$timestamp] INFO: $message\033[0m"
}

log_error() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\033[31m[$timestamp] ERROR: $message\033[0m"
}

# Prompt the user to input the Application ID
read -p "Enter Application ID: " appId

# Prompt the user to input the Service Principal Key
read -s -p "Enter Service Principal Key: " servicePrincipalKey
echo # for newline after the password prompt

# Prompt the user to input the Tenant ID
read -p "Enter Tenant ID: " tenantId

# Log the login action
log_info "Logging in with service principal"

# Login with service principal
az login --service-principal -u $appId -p $servicePrincipalKey --tenant $tenantId

# Prompt the user for the number of days
read -p "Enter the number of days for snapshots to be older than: " n

# Prompt the user to input the Job ID (optional)
read -p "Enter Job ID (optional): " jobId

# Get the current date in seconds since epoch
current_date=$(date +%s)

# Calculate the threshold date in seconds since epoch
threshold_date=$((current_date - n * 86400))  # 86400 seconds in a day

log_info "Threshold date calculated as $(date -d @$threshold_date)"

# Construct the query for snapshots based on the presence of the Job ID
if [ -n "$jobId" ]; then
    log_info "Fetching snapshots with 'cohesity-tag' and Job ID: $jobId"
    snapshots=$(az snapshot list --query "[?tags.\"cohesity-tag\" != null && contains(tags.\"cohesity-tag\", '_${jobId}_') && timeCreated != ''].{id:id, creationTime:timeCreated}" -o tsv)
else
    log_info "Fetching all snapshots with 'cohesity-tag'"
    snapshots=$(az snapshot list --query "[?tags.\"cohesity-tag\" != null && timeCreated != ''].{id:id, creationTime:timeCreated}" -o tsv)
fi

# Initialize an array to store IDs of snapshots to delete
snapshots_to_delete=()

# Loop through each snapshot
while IFS=$'\t' read -r id creation_time; do
    # Convert creation time to seconds since epoch
    creation_date=$(date -d "${creation_time//\"}" +%s)  # Remove quotes from the timestamp

    # Check if the creation time is valid and not 'None'
    if [ -n "$creation_date" ]; then
        # Check if the creation time is older than the threshold
        if [ "$creation_date" -lt "$threshold_date" ]; then
            log_info "Cohesity Snapshot $id was created on $(date -d "${creation_time//\"}")"
            # Add the snapshot ID to the array for deletion
            snapshots_to_delete+=("$id")
        fi
    else
        log_error "Failed to parse creation time: $creation_time"
    fi
done <<< "$snapshots"

# Check if there are snapshots to delete
if [ ${#snapshots_to_delete[@]} -gt 0 ]; then
    log_info "Found ${#snapshots_to_delete[@]} snapshots to delete"
    # Prompt for confirmation
    read -p "Do you want to delete the listed snapshots? Type YES to confirm: " confirmation
    if [ "$confirmation" == "YES" ]; then
        log_info "Deleting Snapshots:"
        for snapshot_id in "${snapshots_to_delete[@]}"; do
            log_info "$snapshot_id"
        done
        # Delete the snapshots
        az snapshot delete --ids "${snapshots_to_delete[@]}"
        log_info "All Snapshots deleted successfully."
    else
        log_info "Deletion cancelled. No snapshots were deleted."
    fi
else
    log_info "No snapshots to delete."
fi