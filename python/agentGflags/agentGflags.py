#!/usr/bin/env python
"""set agent flags"""

import paramiko
import getpass
from datetime import datetime
from sys import exit
import json

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-n', '--flagname', action='append', type=str)
parser.add_argument('-v', '--flagvalue', action='append', type=str)
parser.add_argument('-c', '--clear', action='store_true')

args = parser.parse_args()

servernames = args.servername
serverlist = args.serverlist
username = args.username
password = args.password
flagnames = args.flagname
flagvalues = args.flagvalue
clear = args.clear

if flagnames is None:
    flagnames = []
if flagvalues is None:
    flagvalues = []

if len(flagnames) != len(flagvalues) and not clear:
    print('the number of flag names does not match the number of flag values')
    exit(1)

if password is None:
    password = getpass.getpass("Enter SSH password: ")


def display(myjson):
    """prettyprint dictionary"""
    if isinstance(myjson, list):
        # handle list of results
        for result in myjson:
            print(json.dumps(result, sort_keys=True, indent=4, separators=(', ', ': ')))
    else:
        # or handle single result
        print(json.dumps(myjson, sort_keys=True, indent=4, separators=(', ', ': ')))


# gather server list
def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


servernames = gatherList(servernames, serverlist, name='servers', required=True)
print('')
for server in servernames:
    print(server)
    try:
        # connect to remote host
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(hostname=server, port=22, username=username, password=password)

        # determine config file path
        _stdin, _stdout, _stderr = ssh.exec_command("ps -ef | grep -i linux_agent_exec")
        agentProcess = _stdout.read().decode()
        agentConfigFilePath = agentProcess.split('linux_agent_config_file_path')[1].split(' --')[0].split('=')[1]

        sftp = ssh.open_sftp()
        sftp.get(agentConfigFilePath, 'agent-orig.cfg')

        # edit agent.cfg
        r = open('agent-orig.cfg', 'r')
        w = open('agent.cfg', 'w')

        userSettings = {}

        inSettings = False
        for line in r.readlines():
            if line.startswith('user_settings'):
                inSettings = True
            if inSettings is True:
                if 'name:' in line:
                    settingName = line.split('"')[1]
                if 'value:' in line:
                    settingValue = line.split('"')[1]
                    userSettings[settingName] = settingValue
            if inSettings is False:
                w.write(line)
            if line.startswith('}'):
                inSettings = False

        x = 0
        for flagname in flagnames:
            if clear:
                if flagname in userSettings:
                    del userSettings[flagname]
                    print('  clearing %s' % flagname)
            else:
                userSettings[flagname] = flagvalues[x]
                print('  setting %s: %s' % (flagname, userSettings[flagname]))
            x += 1

        if len(flagnames) > 0:
            w.write('user_settings {\n')
            for flagname in userSettings.keys():
                w.write('  gflag_setting_vec {\n')
                w.write('    name: "%s"\n' % flagname)
                w.write('    value: "%s"\n' % userSettings[flagname])
                w.write('  }\n')
            w.write('}\n')

        r.close()
        w.close()

        if len(flagnames) > 0:
            sftp.put('agent.cfg', '/tmp/agent.cfg')
            now = datetime.now()
            dateString = now.strftime("%Y-%m-%d-%H-%M-%S")
            _stdin, _stdout, _stderr = ssh.exec_command("sudo -S -p '' cp %s %s-%s" % (agentConfigFilePath, agentConfigFilePath, dateString))
            _stdin.write(password + "\n")
            _stdin.flush()
            _stdin, _stdout, _stderr = ssh.exec_command("sudo -S -p '' sudo cp /tmp/agent.cfg %s" % agentConfigFilePath)
            _stdin.write(password + "\n")
            _stdin.flush()
            print('  restarting cohesity agent')
            _stdin, _stdout, _stderr = ssh.exec_command("sudo -S -p '' systemctl restart cohesity-agent.service")
            _stdin.write(password + "\n")
            _stdin.flush()
            print(_stdout.read().decode())
        else:
            print('current settings:')
            display(userSettings)
            print('')

        sftp.close()
        ssh.close()
    except Exception:
        print('  **** an error occurred ****')
        try:
            r.close()
            w.close()
        except Exception:
            pass
        try:
            sftp.close()
            ssh.close()
        except Exception:
            pass
        print('')
