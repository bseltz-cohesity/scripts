#!/usr/bin/env python
import boto3
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-v', '--viewname', type=str, required=True)
parser.add_argument('-o', '--olderthan', type=int, required=True)
parser.add_argument('-x', '--timeunits', type=str, choices=['seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years'], default='days')
parser.add_argument('-t', '--tzoffset', type=int, default=-4)

args = parser.parse_args()

server = args.server
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
viewname = args.viewname
olderthan = args.olderthan
timeunits = args.timeunits
tzoffset = args.tzoffset

# authentication =========================================================
apiauth(vip=server, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

user = api('get', 'sessionUser')

s3 = boto3.resource('s3',
                    endpoint_url='https://%s:3000' % server,
                    aws_access_key_id=user['s3AccessKeyId'],
                    aws_secret_access_key=user['s3SecretKey'])

bucket = s3.Bucket(viewname)

olderthanUsecs = timeAgo(olderthan, timeunits) - (tzoffset * 60 * 60 * 1000000)
print('searching for files older than %s...' % usecsToDate(olderthanUsecs))

# list contents of bucket
for obj in bucket.objects.all():
    objUsecs = dateToUsecs(obj.last_modified.strftime("%Y-%m-%d %H:%M:%S"))
    if objUsecs < olderthanUsecs:
        try:
            s3.Object(viewname, obj.key).delete()
            print('    deleting %s (%s)' % (obj.key, usecsToDate(objUsecs)))
        except Exception as e:
            print(e)
