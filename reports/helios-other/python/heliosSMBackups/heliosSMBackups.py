#!/usr/bin/env python
"""base V1 example"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs
import os

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='admin')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-n', '--numruns', type=int, default=100)
parser.add_argument('-o', '--outfolder', type=str, default='.')
parser.add_argument('-c', '--exportconfig', action='store_true')
parser.add_argument('-k', '--hidesecretkey', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
password = args.password
noprompt = args.noprompt
numruns = args.numruns
outfolder = args.outfolder
exportconfig = args.exportconfig
hidesecretkey = args.hidesecretkey

# authentication =========================================================

apiauth(vip=vip, username=username, password=password, helios=True, prompt=(not noprompt))

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# end authentication =====================================================

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = os.path.join(outfolder, 'heliosSMBackups-%s.csv' % vip)
configfile = os.path.join(outfolder, 'heliosSMBackupConfig-%s.txt' % vip)
f = codecs.open(outfile, 'w')
if exportconfig is True:
    c = codecs.open(configfile, 'w')
# headings
f.write('"Start Time","End Time","Duration (Seconds)","Expiry Date","Location","Status","S3 Host","S3 Bucket"\n')

backups = api('get', 'backup-mgmt/backups?pageSize=%s&page=1' % numruns, mcmv2=True)
config = api('get', 'backup-mgmt/backups/config', mcmv2=True)

retentionDays = config['retentionConfig']['days']

print('\nBackups:\n')

for backup in backups['backupStatuses']:
    startTime = usecsToDate(backup['startTimeMsecs'] * 1000)
    expiryDate = usecsToDate((backup['startTimeMsecs'] + (retentionDays * 86400000)) * 1000)
    endTime = ''
    duration = ''
    if 'endTimeMsecs' in backup:
        endTime = usecsToDate(backup['endTimeMsecs'] * 1000)
        duration = round((backup['endTimeMsecs'] - backup['startTimeMsecs'])/1000)
    print('%s (%s)' % (startTime, backup['status']))
    f.write('"%s","%s","%s","%s","%s","%s","%s","%s"\n' % (startTime, endTime, duration, expiryDate, backup['backupLocation'], backup['status'], backup['s3Host'], backup['s3Bucket']))

f.close()
print('\nOutput saved to %s\n' % outfile)

if exportconfig is True:
    print('Exported config to %s\n' % configfile)
    c.write('host: %s\n' % config['s3Config']['host'])
    c.write('bucket: %s\n' % config['s3Config']['bucket'])
    c.write('accessKey: %s\n' % config['s3Config']['accessKey'])
    if hidesecretkey is not True:
        c.write('secretKey: %s\n' % config['s3Config']['secretKey'])
    c.write('backupFolder: %s\n' % config['s3Config']['backupFolder'])
    c.write('retention: %s days\n' % retentionDays)
    c.close()
