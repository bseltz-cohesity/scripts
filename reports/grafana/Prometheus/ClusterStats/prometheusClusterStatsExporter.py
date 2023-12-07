#!/usr/bin/env python
"""cohesity prometheus exporter example"""

from prometheus_client import start_http_server, Metric, REGISTRY
from pyhesity import *
from time import sleep
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
parser.add_argument('-port', '--port', type=int, default=1234)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
useApiKey = args.useApiKey
password = args.password
port = args.port


class AdvancedDiagnosticsExporter():
    def __init__(self):
        print('collecting stats...')
        self.lastCpu = 0
        self.lastBytes = 0
        self.lastThroughput = 0
        self.firstTimeThrough = True
        pass

    def collect(self):
        if self.firstTimeThrough is True:
            self.firstTimeThrough = False
        else:
            dt = date.today()
            midnight = datetime.combine(dt, datetime.min.time())
            startmsecs = int(dateToUsecs(midnight) / 1000)
            endmsecs = startmsecs + 86400000
            nowmsecs = int(dateToUsecs() / 1000)
            apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, quiet=True)
            # exit if not authenticated
            if apiconnected() is False:
                print('authentication failed')
                exit(1)

            cluster = api('get', 'cluster')

            # cpu percent
            metric_name = '%s_cpu_utilization' % vip
            metric = Metric(metric_name, '%s CPU Utilization Pct' % vip, 'summary')
            try:
                stats = api('get', 'statistics/timeSeriesStats?metricName=kCpuUsagePct&metricUnitType=9&rollupFunction=average&rollupIntervalSecs=180&schemaName=kSentryClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, cluster['id'], endmsecs))
                timestamp = stats['dataPointVec'][-1]['timestampMsecs']
                if timestamp < nowmsecs - 900000:  # stale stat, report 0
                    metric.add_sample(metric_name, value=0, labels={})
                    yield metric
                elif self.lastCpu != timestamp:
                    metric.add_sample(metric_name, value=stats['dataPointVec'][-1]['data']['doubleValue'], labels={})
                    yield metric
                    self.lastCpu = timestamp
            except Exception as e:
                pass

            # bytes backed up
            metric_name = '%s_bytes_backed_up' % vip
            metric = Metric(metric_name, '%s Bytes Backed Up' % vip, 'summary')
            try:
                stats = api('get', 'statistics/timeSeriesStats?metricName=kNumBytesRead&metricUnitType=0&rollupFunction=max&rollupIntervalSecs=120&schemaName=kMagnetoClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, cluster['id'], endmsecs))
                timestamp = stats['dataPointVec'][-1]['timestampMsecs']
                if timestamp < nowmsecs - 120000 or stats['dataPointVec'][-1]['data']['int64Value'] == 0:  # stale stat, report 0
                    metric.add_sample(metric_name, value=0, labels={})
                    yield metric
                elif self.lastBytes != timestamp:
                    metric.add_sample(metric_name, value=stats['dataPointVec'][-1]['data']['int64Value'], labels={})
                    yield metric
                    self.lastBytes = timestamp
                else:
                    metric.add_sample(metric_name, value=0, labels={})
                    yield metric
            except Exception as e:  # no recent stat, report 0
                metric.add_sample(metric_name, value=0, labels={})
                yield metric

            # write throughput
            metric_name = '%s_write_throughput' % vip
            metric = Metric(metric_name, '%s Write Throughput' % vip, 'summary')
            try:
                stats = api('get', 'statistics/timeSeriesStats?metricName=kNumBytesWritten&metricUnitType=5&rollupFunction=max&rollupIntervalSecs=180&schemaName=kBridgeClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, cluster['id'], endmsecs))
                timestamp = stats['dataPointVec'][-1]['timestampMsecs']
                if timestamp < nowmsecs - 180000 or stats['dataPointVec'][-1]['data']['int64Value'] == 0:  # stale stat, report 0
                    metric.add_sample(metric_name, value=0, labels={})
                    yield metric
                elif self.lastThroughput != timestamp:
                    metric.add_sample(metric_name, value=stats['dataPointVec'][-1]['data']['int64Value'], labels={})
                    yield metric
                    self.lastThroughput = timestamp
            except Exception as e:  # no recent stat, report 0
                metric.add_sample(metric_name, value=0, labels={})
                yield metric

            # morphed garbage
            metric_name = '%s_morphed_garbage' % vip
            metric = Metric(metric_name, '%s Morphed Garbage' % vip, 'summary')
            try:
                stats = api('get', 'statistics/timeSeriesStats?metricName=kMorphedGarbageBytes&metricUnitType=0&range=week&rollupFunction=average&rollupIntervalSecs=720&schemaName=kBridgeClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, cluster['id'], endmsecs))
                timestamp = stats['dataPointVec'][-1]['timestampMsecs']
                metric.add_sample(metric_name, value=stats['dataPointVec'][-1]['data']['int64Value'], labels={})
                yield metric
            except Exception as e:  # no recent stat, report 0
                pass


if __name__ == '__main__':
    start_http_server(port=port)
    REGISTRY.register(AdvancedDiagnosticsExporter())
    while True:
        sleep(5)
