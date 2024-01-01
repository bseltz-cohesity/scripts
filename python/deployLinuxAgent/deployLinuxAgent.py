#!/usr/bin/env python
"""deploy linux agent"""

import paramiko
import getpass
import os
from sys import exit

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-f', '--filepath', type=str, required=True)
parser.add_argument('-a', '--agentuser', type=str, default='root')

args = parser.parse_args()

servernames = args.servername
serverlist = args.serverlist
username = args.username
password = args.password
filepath = args.filepath
agentuser = args.agentuser

file, file_extension = os.path.splitext(filepath)
filename = os.path.basename(filepath)


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

if password is None:
    password = getpass.getpass("Enter SSH password: ")

for server in servernames:
    print('\n%s' % server)
    try:

        # connect to remote host
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(hostname=server, port=22, username=username, password=password)

        # check for installers
        installer = None
        installerType = 'rpm'

        if installer is None:
            _stdin, _stdout, _stderr = ssh.exec_command("which dnf")
            dnf = _stdout.read().decode()
            if dnf:
                installer = 'dnf -y install'

        if installer is None:
            _stdin, _stdout, _stderr = ssh.exec_command("which yum")
            yum = _stdout.read().decode()
            if yum:
                installer = 'yum -y localinstall'

        if installer is None:
            _stdin, _stdout, _stderr = ssh.exec_command("which zypper")
            zypper = _stdout.read().decode()
            if zypper:
                installer = 'zypper --non-interactive in'

        if installer is None:
            _stdin, _stdout, _stderr = ssh.exec_command("which apt-get")
            apt = _stdout.read().decode()
            if apt:
                installerType = 'deb'
                installer = 'apt-get -y install'

        if installer is None:
            print('  **** could not determine install command for this host (dnf, yum, apt-get, zypper) ****')
            ssh.close()
            continue
        elif installerType == 'rpm' and file_extension.lower() != '.rpm':
            print('  **** this host requires an .rpm installer ****')
            ssh.close()
            continue
        elif installerType == 'deb' and file_extension.lower() != '.deb':
            print('  **** this host requires a .deb installer ****')
            ssh.close()
            continue

        print('  copying installer...')
        sftp = ssh.open_sftp()
        sftp.put(filepath, '/tmp/%s' % filename)

        print('  installing agent...')
        _stdin, _stdout, _stderr = ssh.exec_command("printf '#!/bin/bash\nexport COHESITYUSER=%s\n%s /tmp/%s\n' > installcohesityagent.sh && chmod +x installcohesityagent.sh && sudo -S -p '' ./installcohesityagent.sh" % (agentuser, installer, filename))
        _stdin.write(password + "\n")
        _stdin.flush()
        response = _stdout.read().decode()
        print(response)

        print('  removing installer...')
        _stdin, _stdout, _stderr = ssh.exec_command("rm -f installcohesityagent.sh")
        _stdin, _stdout, _stderr = ssh.exec_command("rm -f /tmp/%s" % filename)

        sftp.close()
        ssh.close()
    except Exception:
        print('  **** an error occurred ****')
        try:
            sftp.close()
            ssh.close()
        except Exception:
            pass
