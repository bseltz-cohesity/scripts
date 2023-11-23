#!/usr/bin/env python
"""Clone a View Directory Using python"""

# usage: ./cloneDirectory.py -s mycluster -u admin -d local -sp /MyView/folder1 -dp /MyView -nd folder2
# the above example copies /MyView/folder1 to /MyView/folder2

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from time import sleep, time
import codecs
import os
import glob

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-s', '--sourcepath', type=str, required=True)
parser.add_argument('-t', '--targetpath', type=str, required=True)
parser.add_argument('-l', '--logdir', type=str, default='.')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
sourcepath = args.sourcepath
targetpath = args.targetpath
logdir = args.logdir


if logdir is not None:
    sleep(5)
    now = time()
    try:
        listing = glob.glob(os.path.join(logdir, 'cloneLog-*.txt'))
        for f in listing:
            if os.path.isfile(f):
                if os.stat(f).st_mtime < now - 7 * 86400:
                    os.remove(f)
    except Exception:
        pass
    now = datetime.now()
    nowstring = now.strftime("%Y-%m-%d-%H-%M-%S")
    logfilename = os.path.join(logdir, 'cloneLog-%s.txt' % nowstring)
    try:
        log = codecs.open(logfilename, 'w')
        log.write('%s: Script started\n\n' % nowstring)
    except Exception:
        print('Unable to open log file' % logfilename)
        exit(1)


def out(message, quiet=False):
    if quiet is not True:
        print(message)
    if logdir is not None:
        log.write('%s\n' % message)


def bail(code=0):
    if logdir is not None:
        log.close()
    exit(code)


sourcepath = sourcepath.replace('\\', '/').replace('//', '/')
targetpath = targetpath.replace('\\', '/').replace('//', '/')

if sourcepath[0] == '/':
    sourcepath = sourcepath[1:]

if targetpath[0] == '/':
    targetpath = targetpath[1:]

if '/' not in targetpath:
    out('targetPath must be a new folder name')
    bail(1)

(targetview, targetpath) = targetpath.rsplit('/', 1)

if targetpath == '':
    out('targetPath must be a new folder name')
    bail(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        out('-clustername is required when connecting to Helios or MCM')
        bail(1)

# exit if not authenticated
if apiconnected() is False:
    out('authentication failed')
    bail(1)

# clone directory params
CloneDirectoryParams = {
    'destinationDirectoryName': targetpath,
    'destinationParentDirectoryPath': '/%s' % targetview,
    'sourceDirectoryPath': '/%s' % sourcepath
}

# clone directory
out("Cloning %s to %s/%s..." % (sourcepath, targetview, targetpath))
result = api('post', 'views/cloneDirectory', CloneDirectoryParams)
if result is not None and 'error' in result:
    if logdir:
        out('%s\n' % result['error'], quiet=True)
    if 'KViewAlreadyExists' not in result['error']:
        bail(1)
sleep(5)
bail(0)
