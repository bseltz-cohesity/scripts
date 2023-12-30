#!/usr/bin/env python
"""deploy linux agent"""

import paramiko
import getpass
import os
from sys import exit

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-f', '--filepath', type=str, required=True)

args = parser.parse_args()

server = args.server
username = args.username
password = args.password
filepath = args.filepath

file, file_extension = os.path.splitext(filepath)
filename = os.path.basename(filepath)

if password is None:
    password = getpass.getpass("Enter SSH password: ")

# connect to remote host
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=server, port=22, username=username, password=password)


def bail():
    ssh.close()
    exit()


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
    print('could not determine install command for this host (dnf, yum, apt-get, zypper)')
    bail()
elif installerType == 'rpm' and file_extension.lower() != '.rpm':
    print('this host requires an .rpm installer')
    bail()
elif installerType == 'deb' and file_extension.lower() != '.deb':
    print('this host requires a .deb installer')
    bail()

print('copying installer...')
sftp = ssh.open_sftp()
sftp.put(filepath, '/tmp/%s' % filename)

print('installing agent...')
_stdin, _stdout, _stderr = ssh.exec_command("sudo -S -p '' %s /tmp/%s" % (installer, filename))
_stdin.write(password + "\n")
_stdin.flush()
response = _stdout.read().decode()
print(response)

print('removing installer...')
_stdin, _stdout, _stderr = ssh.exec_command("rm -f /tmp/%s" % filename)

sftp.close()
ssh.close()
