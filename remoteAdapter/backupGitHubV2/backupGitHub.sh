#!/bin/bash

# Configuration variables to set specific to your environment
COHESITY_MOUNT_PATH="cohesity-cluster:/view-name"
LOCAL_MOUNT_POINT="/mnt/GitHub-Repos"
GITHUB_ORG="organization_name"         # This is a GitHub organization name that the repositories reside in
GITHUB_PAT="ghp_private_access_token"  # This is a legacy personal access token that must begin with ghp_

# Initial Setup (comment out after first run)
# ===========================================
# sudo mkdir -p /mnt/GitHub-Scripts
# sudo chown cohesity-script:cohesity-script /mnt/GitHub-Scripts/
# sudo yum install -y git jq

# Always Run
# ============
# Mounting the view and setting permissions
LOCAL_USER=`whoami`
sudo mount -t nfs -o soft,intr,noatime,retrans=1000,timeo=900,retry=5,rsize=1048576,wsize=1048576,nolock $COHESITY_MOUNT_PATH $LOCAL_MOUNT_POINT
sudo chown $LOCAL_USER:$LOCAL_USER $LOCAL_MOUNT_POINT
cd $LOCAL_MOUNT_POINT

# Getting list of repositories from the specified organization
REPOS=`curl -s -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_PAT" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/orgs/$GITHUB_ORG/repos | jq '.[].name?' | sed 's/"//g'`

# Looping through all repositories and either cloning
# if not present or pulling to refresh the repository
for repo in $REPOS
do
	if [ ! -d $repo ]; then
		git clone https://github.com/$GITHUB_ORG/$repo
	else
		cd $repo
		git pull
		cd ..
	fi
done

# Finally, unmount the view
cd ~
sudo umount -l $LOCAL_MOUNT_POINT
