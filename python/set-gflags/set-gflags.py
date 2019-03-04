#!/usr/bin/env python

import requests
import datetime
import sys
import os
import subprocess
import json

### constants
SCRIPTFOLDER = sys.path[0]
LOGFILE = os.path.join(SCRIPTFOLDER, 'set-gflags-log.txt')
port = {
    'magneto': '20000',
    'bridge': '11111'
}

### settings
my_timezone = -5 # eastern time zone
cluster_timezone = -8 # pacific time zone

morning = 7 # 7:00 AM
night = 17 # 5:00 PM

night_flags = (
    {'service': 'magneto', 'name': 'magneto_gatekeeper_max_tasks_per_generic_nas_entity', 'value': '8', 'reason': 'performance'},
    {'service': 'bridge', 'name': 'bridge_magneto_nas_max_active_read_write_ops', 'value': '32', 'reason': 'performance'}
    )

morning_flags = (
    {'service': 'magneto', 'name': 'magneto_gatekeeper_max_tasks_per_generic_nas_entity', 'value': '4', 'reason': 'performance'},
    {'service': 'bridge', 'name': 'bridge_magneto_nas_max_active_read_write_ops', 'value': '20', 'reason': 'performance'}
    )

### start logging
f = open(LOGFILE, 'w')
f.write('%s\n' % datetime.datetime.now())

### time of day calc
offset = cluster_timezone - my_timezone
hour = int(datetime.datetime.now().strftime("%H")) - offset

if hour >= night or hour < morning:
    # night time
    f.write('applying nighttime flags...\n')
    flags = night_flags
else:
    # day time
    f.write('applying daytime flags...\n')
    flags = morning_flags

### get nodes
clusterid = json.loads(open('/home/cohesity/data/cluster_id.json').read())['id']
nodes = []
nodecmd = ["/home/cohesity/bin/hostips"]
proc = subprocess.Popen(nodecmd, stdout=subprocess.PIPE)
nodes = proc.stdout.readlines()[0].split()

### apply flags

### persistent save
for flag in flags:
    saveflag = {
        'clusterId': clusterid,
        'serviceName': flag['service'],
        'gflags': [
            {
            'name': flag['name'],
            'value': flag['value'],
            'reason': flag['reason']
            }
        ]
    }
    response = requests.post('http://localhost:23456/nexus/v1/cluster/update_gflags', json=saveflag, verify=False)
    f.write('%s' % response.json()['message'])

### effective now
for node in nodes:
    for flag in flags:
        message = ''
        response = requests.get('http://%s:%s/flagz?%s=%s' % (node, port[flag['service']], flag['name'], flag['value']), verify=False)
        try:
            message = response.content[response.content.rindex('<pre>')+5:].split("\n")[0].split("</pre>")[0]
        except expression as identifier:
            message = 'something went wrong setting %s:%s' % (node, flag)
        f.write('%s %s\n' % (node, message))

### close log file
f.close()

# crontab -e
# */10 * * * * /home/cohesity/scripts/set-gflags.py