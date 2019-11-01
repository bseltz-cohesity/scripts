#!/usr/bin/env python
"""Schedule Jobs in Python"""

### usage: ./jobScheduler.py -g mygroup -j job1 -j job2 -j job3

import os

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-g', '--groupname', type=str, required=True)
parser.add_argument('-j', '--jobname', action='append', type=str, required=True)

args = parser.parse_args()

groupname = args.groupname
jobs = args.jobname

### create group folder
scriptdir = os.path.dirname(os.path.realpath(__file__))
grouppath = os.path.join(scriptdir, groupname.lower())
if os.path.isdir(grouppath) is False:
    os.mkdir(grouppath)

### create trigger files
for job in jobs:
    triggerfilepath = os.path.join(grouppath, job.lower())
    f = open(triggerfilepath, 'w')
    f.write('not started')
    f.close()
