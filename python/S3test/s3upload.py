#!/usr/bin/env python
import boto3
import time

cohesitycluster = 'mycluster'
accesskey = 'Oorht1mLTr39TmsxWTh3PQsHsVYfjGVWKgoXd0kAtqQ'
secretkey = '_xRTQHHrAMDB3g7hQAJktlu6aevwQ-MERzlw8B7RwKrk'
viewname = 'mys3view'
filename = '200MB.zip'

s3 = boto3.resource('s3',
                    endpoint_url='https://%s:3000' % cohesitycluster,
                    aws_access_key_id=accesskey,
                    aws_secret_access_key=secretkey)

bucket = s3.Bucket(viewname)

for obj in bucket.objects.all():
    print(obj.key)

start = time.time()
try:
    s3.Object(viewname, filename).upload_file(filename)
except Exception as e:
    pass
elapsed_time = time.time() - start
milli_secs = int(round(elapsed_time * 1000))
print(milli_secs)
