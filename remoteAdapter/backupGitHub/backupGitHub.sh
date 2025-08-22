#!/bin/bash

# Initial Setup (comment out after first run)
# ===========================================
# sudo mkdir -p /mnt/GitHub-Scripts
# sudo chown cohesity-script:cohesity-script /mnt/GitHub-Scripts/
# sudo chmod 755 /mnt/GitHub-Scripts/
# sudo yum install -y git

# Always Run
# ============
sudo mount -t nfs -o soft,intr,noatime,retrans=1000,timeo=900,retry=5,rsize=1048576,wsize=1048576,nolock mycohesity:/GitHub-Scripts /mnt/GitHub-Scripts/
cd /mnt/GitHub-Scripts/

# Inital Setup (comment out after first run)
# ============================================
# git clone https://github.com/cohesity/community-automation-samples.git
# git clone https://github.com/otherguy/anotherrepo.git

# Always Run
# ============
cd scripts/
git pull
# cd ../anotherrepo
# git pull
cd ~
sudo umount /mnt/GitHub-Scripts/
