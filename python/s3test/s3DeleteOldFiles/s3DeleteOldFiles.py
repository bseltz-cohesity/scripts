#!/usr/bin/env python
import boto3
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-b', '--bucketname', type=str, required=True)
parser.add_argument('-o', '--olderthan', type=int, required=True)
parser.add_argument('-m', '--timeunits', type=str, choices=['seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years'], default='days')
parser.add_argument('-t', '--tzoffset', type=int, default=0)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
bucketname = args.bucketname
olderthan = args.olderthan
timeunits = args.timeunits
tzoffset = args.tzoffset

### authenticate
apiauth(vip, username, domain)

# get cohesity user s3 credentials
user = [u for u in api('get', 'users') if u['username'].lower() == username.lower() and u['domain'].lower() == domain.lower()]
if not user:
    print("User '%s' not found" % username)
    exit(1)

s3 = boto3.resource('s3',
                    endpoint_url='https://%s:3000' % vip,
                    aws_access_key_id=user[0]['s3AccessKeyId'],
                    aws_secret_access_key=user[0]['s3SecretKey'],
                    verify=False)

bucket = s3.Bucket(bucketname)

olderthanUsecs = timeAgo(olderthan, timeunits) - (tzoffset * 60 * 60 * 1000000)
print('searching for files older than %s...' % usecsToDate(olderthanUsecs))

# list contents of bucket
for obj in bucket.objects.all():
    objUsecs = dateToUsecs(obj.last_modified.strftime("%Y-%m-%d %H:%M:%S"))
    if objUsecs < olderthanUsecs:
        try:
            s3.Object(bucketname, obj.key).delete()
            print('    deleting %s (%s)' % (obj.key, usecsToDate(objUsecs)))
        except Exception as e:
            print(e)
