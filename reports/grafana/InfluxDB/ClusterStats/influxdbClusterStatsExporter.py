#!/usr/bin/env python
"""cohesity influxdb example"""

import influxdb_client
# import os
from pyhesity import *
from time import sleep
from influxdb_client import Point  # InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS
from datetime import date
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
useApiKey = args.useApiKey
password = args.password

if (vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

token = 'BapMQGVqAJ4CQTVWYrACnfzBVNRfhFhtZanypjjMmySIPenGhe5u_EgOBJDVT7fECcsncgFuhiv56BptlQ-DLA=='
org = "MyCompany"
url = "http://localhost:8086"
bucket = "cohesity"

write_client = influxdb_client.InfluxDBClient(url=url, token=token, org=org)
write_api = write_client.write_api(write_options=SYNCHRONOUS)

lastCpu = 0
lastBytes = 0
lastThroughput = 0

print('collecting stats...')

while True:
    dt = date.today()
    midnight = datetime.combine(dt, datetime.min.time())
    startmsecs = int(dateToUsecs(midnight) / 1000)
    endmsecs = startmsecs + 86400000
    nowmsecs = int(dateToUsecs() / 1000)
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, quiet=True)
    cluster = api('get', 'cluster')

    # cpu percent
    try:
        stats = api('get', 'statistics/timeSeriesStats?metricName=kCpuUsagePct&metricUnitType=9&rollupFunction=average&rollupIntervalSecs=180&schemaName=kSentryClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, cluster['id'], endmsecs))
        timestamp = stats['dataPointVec'][-1]['timestampMsecs']
        if timestamp < nowmsecs - 900000:  # stale stat, report 0
            point = (
                Point("cpu_percent")
                .tag("tagname1", "cpu_percent")
                .field("field1", 0.0)
            )
            write_api.write(bucket=bucket, org=org, record=point)
        elif lastCpu != timestamp:  # fresh stat
            point = (
                Point("cpu_percent")
                .tag("tagname1", "cpu_percent")
                .field("field1", stats['dataPointVec'][-1]['data']['doubleValue'])
            )
            write_api.write(bucket=bucket, org=org, record=point)
            lastCpu = timestamp
    except Exception as e:
        print(e)

    # bytes backed up
    try:
        stats = api('get', 'statistics/timeSeriesStats?metricName=kNumBytesRead&metricUnitType=0&rollupFunction=max&rollupIntervalSecs=120&schemaName=kMagnetoClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, cluster['id'], endmsecs))
        timestamp = stats['dataPointVec'][-1]['timestampMsecs']
        if timestamp < nowmsecs - 120000 or stats['dataPointVec'][-1]['data']['int64Value'] == 0:  # stale stat, report 0
            point = (
                Point("bytes_backed_up")
                .tag("tagname1", "bytes_backed_up")
                .field("field1", 0)
            )
            write_api.write(bucket=bucket, org=org, record=point)
        elif lastBytes != timestamp:  # fresh stat
            point = (
                Point("bytes_backed_up")
                .tag("tagname1", "bytes_backed_up")
                .field("field1", stats['dataPointVec'][-1]['data']['int64Value'])
            )
            write_api.write(bucket=bucket, org=org, record=point)
            lastBytes = timestamp
        else:
            point = (
                Point("bytes_backed_up")
                .tag("tagname1", "bytes_backed_up")
                .field("field1", 0)
            )
            write_api.write(bucket=bucket, org=org, record=point)
    except Exception as e:  # no recent stat, report 0
        print(e)
        point = (
            Point("bytes_backed_up")
            .tag("tagname1", "bytes_backed_up")
            .field("field1", 0)
        )
        write_api.write(bucket=bucket, org=org, record=point)

    # write throughput
    try:
        stats = api('get', 'statistics/timeSeriesStats?metricName=kNumBytesWritten&metricUnitType=5&rollupFunction=max&rollupIntervalSecs=180&schemaName=kBridgeClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, cluster['id'], endmsecs))
        timestamp = stats['dataPointVec'][-1]['timestampMsecs']
        if timestamp < nowmsecs - 180000 or stats['dataPointVec'][-1]['data']['int64Value'] == 0:  # stale stat, report 0
            point = (
                Point("write_throughput")
                .tag("tagname1", "write_throughput")
                .field("field1", 0)
            )
            write_api.write(bucket=bucket, org=org, record=point)
        elif lastThroughput != timestamp:  # fresh stat
            point = (
                Point("write_throughput")
                .tag("tagname1", "write_throughput")
                .field("field1", stats['dataPointVec'][-1]['data']['int64Value'])
            )
            write_api.write(bucket=bucket, org=org, record=point)
            lastThroughput = timestamp
    except Exception as e:  # no recent stat, report 0
        print(e)
        point = (
            Point("write_throughput")
            .tag("tagname1", "write_throughput")
            .field("field1", 0)
        )
        write_api.write(bucket=bucket, org=org, record=point)

    sleep(60)
