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
    cpustats = api('get', 'statistics/timeSeriesStats?metricName=kCpuUsagePct&metricUnitType=9&rollupFunction=average&rollupIntervalSecs=180&schemaName=kSentryClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, cluster['id'], endmsecs))
    backupstats = api('get', 'statistics/timeSeriesStats?metricName=kNumBytesRead&metricUnitType=0&rollupFunction=max&rollupIntervalSecs=120&schemaName=kMagnetoClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, cluster['id'], endmsecs))
    throughputstats = api('get', 'statistics/timeSeriesStats?metricName=kNumBytesWritten&metricUnitType=5&rollupFunction=max&rollupIntervalSecs=180&schemaName=kBridgeClusterStats&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (startmsecs, cluster['id'], endmsecs))
    return {'stats': {'cpustats': cpustats, 'backupstats': backupstats, 'throughputstats': throughputstats}}


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8443, ssl_context=('myhost_crt.pem', 'myhost_key.pem'))
