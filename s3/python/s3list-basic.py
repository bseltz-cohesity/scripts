#!/usr/bin/env python
import boto3

cohesitycluster = 'mycluster'
accesskey = 'soz8UmIsN8hLHNfmf0gr8M-cIuDlcdRf3jA3bkphkEA'
secretkey = '3gnUMvsp8nxYLPUWneH5v8L3TRZ3vQDt3pb3lblzS-g'
viewname = 'myview'

s3 = boto3.resource('s3',
                    endpoint_url='https://%s:3000' % cohesitycluster,
                    aws_access_key_id=accesskey,
                    aws_secret_access_key=secretkey)

bucket = s3.Bucket(viewname)

# list contents of bucket
print('')
for obj in bucket.objects.all():
    print(obj.key)
print('')
