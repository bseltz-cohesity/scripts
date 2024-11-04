#!/usr/bin/env python
"""replace linux agent certificate"""

import warnings
warnings.filterwarnings(action='ignore', module='.*paramiko.*')
import paramiko
import getpass
from datetime import datetime
from sys import exit

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--servername', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-f', '--certfile', type=str, default=None)

args = parser.parse_args()

server = args.servername
username = args.username
password = args.password
certfile = args.certfile

if password is None:
    password = getpass.getpass("Enter SSH password: ")

print('')
print(server)
try:
    if certfile is None:
        certfile = 'server_cert-%s' % server

    # connect to remote host
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(hostname=server, port=22, username=username, password=password)

    # determine config file path
    _stdin, _stdout, _stderr = ssh.exec_command("ps -ef | grep -i linux_agent_exec")
    agentProcess = _stdout.read().decode()
    agentCertFilePath = agentProcess.split('linux_agent_cert_file_path')[1].split(' --')[0].split('=')[1]

    # rename existing server_cert file
    print('  renaming %s -> %s-orig' % (agentCertFilePath, agentCertFilePath))
    _stdin, _stdout, _stderr = ssh.exec_command("sudo -S -p '' sudo mv %s %s-orig" % (agentCertFilePath, agentCertFilePath))
    _stdin.write(password + "\n")
    _stdin.flush()

    # copy new cert into place
    print('  copying %s -> %s' % (certfile, agentCertFilePath))
    sftp = ssh.open_sftp()
    sftp.put(certfile, agentCertFilePath)

    # restart agent
    print('  restarting cohesity agent...')
    _stdin, _stdout, _stderr = ssh.exec_command("sudo -S -p '' systemctl restart cohesity-agent.service")
    _stdin.write(password + "\n")
    _stdin.flush()
    print(_stdout.read().decode())

    sftp.close()
    ssh.close()
except Exception:
    print('  **** an error occurred ****')
    try:
        sftp.close()
        ssh.close()
    except Exception:
        pass
    print('')
