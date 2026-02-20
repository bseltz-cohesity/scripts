#!/bin/bash

# Initial Setup (comment out after first run)
# ===========================================
# sudo mkdir -p /mnt/GitHub-Scripts
# sudo chown cohesity-script:cohesity-script /mnt/GitHub-Scripts/
# sudo chmod 755 /mnt/GitHub-Scripts/
# sudo yum install -y git

# Always Run
# ============
sudo mount -t nfs -o soft,intr,noatime,retrans=1000,timeo=900,retry=5,rsize=1048576,wsize=1048576,nolock ve4:/GitHub-Scripts /mnt/GitHub-Scripts/
cd /mnt/GitHub-Scripts/

rm -rf scripts.git
git clone --mirror https://github.com/bseltz-cohesity/scripts.git
cd ~
sudo umount /mnt/GitHub-Scripts/
