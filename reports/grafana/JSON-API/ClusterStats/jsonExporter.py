#!/usr/bin/env python3
from flask import Flask, request
from flask_cors import CORS
from pyhesity import *
from datetime import date
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'some random string'
app.debug = True
CORS(app)


@app.route("/stats", methods=['GET'])
def getstats():
    apiKey = request.headers.get('apiKey', 0)
    if apiKey == 0:
        return "", 403
    vip = request.args.get('vip', '')
    if vip == '':
        return "", 403
    print(vip)
    dt = date.today()
    midnight = datetime.combine(dt, datetime.min.time())
    startmsecs = int(dateToUsecs(midnight) / 1000) - (86400000 * 7)
    endmsecs = startmsecs + (86400000 * 8)
    apiauth(vip=vip, username='helios', domain='local', password=apiKey, useApiKey=True, noretry=True)
    cluster = api('get', 'cluster')
    clusterId = cluster['id']

    # CPU utilization (%)
    cpustats = api('get', 'statistics/timeSeriesStats?metricName=kCpuUsagePct&metricUnitType=9&rollupFunction=average&rollupIntervalSecs=180&schemaName=kSentryClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, clusterId, endmsecs))

    # Memory utilization (%)
    memorystats = api('get', 'statistics/timeSeriesStats?metricName=kMemoryUsagePct&metricUnitType=9&rollupFunction=average&rollupIntervalSecs=180&schemaName=kSentryClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, clusterId, endmsecs))

    # Bytes read from backup source (kept for backward compatibility)
    backupstats = api('get', 'statistics/timeSeriesStats?metricName=kNumBytesRead&metricUnitType=0&rollupFunction=max&rollupIntervalSecs=120&schemaName=kMagnetoClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, clusterId, endmsecs))

    # Write throughput (kept for backward compatibility)
    throughputstats = api('get', 'statistics/timeSeriesStats?metricName=kNumBytesWritten&metricUnitType=5&rollupFunction=max&rollupIntervalSecs=180&schemaName=kBridgeClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, clusterId, endmsecs))

    # Read/Write IOPS (cluster-wide, from Cluster Logical Stats)
    readiopsstats = api('get', 'statistics/timeSeriesStats?metricName=kReadIos&rollupFunction=average&rollupIntervalSecs=180&schemaName=kBridgeClusterLogicalStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, clusterId, endmsecs))
    writeiopsstats = api('get', 'statistics/timeSeriesStats?metricName=kWriteIos&rollupFunction=average&rollupIntervalSecs=180&schemaName=kBridgeClusterLogicalStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, clusterId, endmsecs))

    # Read/Write latency (microseconds, cluster-wide)
    readlatencystats = api('get', 'statistics/timeSeriesStats?metricName=kReadLatencyUsecs&rollupFunction=average&rollupIntervalSecs=180&schemaName=kBridgeClusterLogicalStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, clusterId, endmsecs))
    writelatencystats = api('get', 'statistics/timeSeriesStats?metricName=kWriteLatencyUsecs&rollupFunction=average&rollupIntervalSecs=180&schemaName=kBridgeClusterLogicalStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, clusterId, endmsecs))

    # Morphed garbage (bytes, cluster-wide)
    morphedgarbagestats = api('get', 'statistics/timeSeriesStats?metricName=kMorphedGarbageBytes&metricUnitType=0&range=week&rollupFunction=average&rollupIntervalSecs=720&schemaName=kBridgeClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, clusterId, endmsecs))

    return {'stats': {
        'cpustats': cpustats,
        'memorystats': memorystats,
        'backupstats': backupstats,
        'throughputstats': throughputstats,
        'readiopsstats': readiopsstats,
        'writeiopsstats': writeiopsstats,
        'readlatencystats': readlatencystats,
        'writelatencystats': writelatencystats,
        'morphedgarbagestats': morphedgarbagestats,
    }}


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8443, ssl_context=('myhost_crt.pem', 'myhost_key.pem'))
