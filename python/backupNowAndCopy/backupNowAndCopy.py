#!/usr/bin/env python
"""Backup Now and Copy for python"""

### usage: ./backupNowAndCopy.py -v mycluster -u admin -j 'Generic NAS'

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobName', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobName = args.jobName

### authenticate
apiauth(vip, username, domain)

### find protectionJob
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
if not job:
    print "Job '%s' not found" % jobName
    exit()

### get policy settings for job
policy = api('get', 'protectionPolicies/%s' % job[0]['policyId'])
archiveRetention = policy['snapshotArchivalCopyPolicies'][0]['daysToKeep']
archiveTarget = policy['snapshotArchivalCopyPolicies'][0]['target']
replicaRetention = policy['snapshotReplicationCopyPolicies'][0]['daysToKeep']
replicaTarget = policy['snapshotReplicationCopyPolicies'][0]['target']

### run protectionJob
print "Running %s..." % jobName

runNowTask = {
  "copyRunTargets": [
    {
      "archivalTarget": archiveTarget,
      "daysToKeep": archiveRetention,
      "type": "kArchival"
    },
    {
      "daysToKeep": replicaRetention,
      "replicationTarget": replicaTarget,
      "type": "kRemote"
    }
  ],
  "sourceIds": [],
  "runType": "kRegular"
}

api('post', "protectionJobs/run/%s" % job[0]['id'], runNowTask)


