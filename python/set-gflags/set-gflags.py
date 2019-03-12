#!/usr/bin/env python

import requests
import datetime
import sys
import os
import subprocess
import json

### constants
SCRIPTFOLDER = sys.path[0]
LOGFILE = os.path.join(SCRIPTFOLDER, 'gflags-log.txt')
port = {
    'magneto': '20000',
    'bridge': '11111'
}

### settings
morning = 7  # 7:00 AM
night = 18  # 6:00 PM

### timezones
my_timezone = -5  # eastern time zone
cluster_timezone = -8  # pacific time zone

### flags
night_flags = (
    {'service': 'magneto', 'name': 'magneto_gatekeeper_max_tasks_per_generic_nas_entity', 'value': '8', 'reason': 'smb_throughput'},
    {'service': 'bridge', 'name': 'bridge_magneto_nas_max_active_read_write_ops', 'value': '32', 'reason': 'Diff_Streamer'}
)

morning_flags = (
    {'service': 'magneto', 'name': 'magneto_gatekeeper_max_tasks_per_generic_nas_entity', 'value': '4', 'reason': 'smb_throughput'},
    {'service': 'bridge', 'name': 'bridge_magneto_nas_max_active_read_write_ops', 'value': '20', 'reason': 'Diff_Streamer'}
)

night_commands = (
    '/home/cohesity/software/crux/bin/allssh.sh smb_proxy.sh stop',
    '/home/cohesity/software/crux/bin/allssh.sh smb_proxy.sh start --gpl_util_grpc_thread_count=100'
)

morning_commands = (
    '/home/cohesity/software/crux/bin/allssh.sh smb_proxy.sh stop',
    '/home/cohesity/software/crux/bin/allssh.sh smb_proxy.sh start --gpl_util_grpc_thread_count=32'
)

### start logging
f = open(LOGFILE, 'w')
f.write('%s\n' % datetime.datetime.now())

### time of day calc
offset = cluster_timezone - my_timezone
hour = int(datetime.datetime.now().strftime("%H")) - offset

### execute shell command function
my_env = os.environ.copy()
my_env['PATH'] = '/home/cohesity/software/toolchain/x86_64-linux/6.1/bin:/home/cohesity/software/crux/bin/tools:/home/cohesity/software/toolchain/x86_64-linux/6.1/bin:/home/cohesity/software/crux/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/cohesity/.local/bin:/home/cohesity/bin'


def execcmd(command):
    proc = subprocess.Popen(command, shell=True, stdout=f, stderr=f, cwd=SCRIPTFOLDER, env=my_env)
    proc.communicate()


### get settings for time of day
if hour >= night or hour < morning:
    # night time
    f.write('applying nighttime flags...\n')
    flags = night_flags
    commands = night_commands
else:
    # day time
    f.write('applying daytime flags...\n')
    flags = morning_flags
    commands = morning_commands

### execute commands
for cmd in commands:
    execcmd(cmd)

### get nodes
clusterid = json.loads(open('/home/cohesity/data/cluster_id.json').read())['id']
nodes = []
nodecmd = "/home/cohesity/bin/hostips"
proc = subprocess.Popen([nodecmd], shell=True, stdout=subprocess.PIPE, cwd=SCRIPTFOLDER, env=dict(os.environ))
nodes = proc.stdout.readlines()[0].split()

### save flags
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

### make flags effective now
for node in nodes:
    for flag in flags:
        message = ''
        response = requests.get('http://%s:%s/flagz?%s=%s' % (node, port[flag['service']], flag['name'], flag['value']), verify=False)
        try:
            message = response.content[response.content.rindex('<pre>') + 5:].split("\n")[0].split("</pre>")[0]
        except Exception:
            message = 'something went wrong setting %s:%s' % (node, flag)
        f.write('%s %s\n' % (node, message))

### close log file
f.close()

# remember to set crontab based on pacific time zone (e.g. 7am est = 4, 6pm est = 15)
# crontab -e
# 0 4,15 * * * /home/cohesity/scripts/set-gflags.py
