#!/usr/bin/env python

### import Cohesity python module
from datetime import datetime
import smtplib
import email.message
import email.utils
import time
import json
import requests
import urllib3
import argparse
import requests.packages.urllib3

### command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-pw', '--password', type=str, required=True)
parser.add_argument('-s', '--mailserver', type=str)
parser.add_argument('-p', '--mailport', type=int, default=25)
parser.add_argument('-t', '--sendto', action='append', type=str)
parser.add_argument('-f', '--sendfrom', type=str)
parser.add_argument('-b', '--maxbackuphrs', type=int, default=8)
parser.add_argument('-r', '--maxreplicationhrs', type=int, default=12)
parser.add_argument('-w', '--watch', type=str, choices=['all', 'backup', 'replication'], default='all')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom
maxbackuphrs = args.maxbackuphrs
maxreplicationhrs = args.maxreplicationhrs
watch = args.watch

# pyhesity ================================================================

requests.packages.urllib3.disable_warnings()
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

APIROOT = ''
HEADER = ''
AUTHENTICATED = False
APIMETHODS = ['get', 'post', 'put', 'delete']


### authentication
def apiauth(vip='helios.cohesity.com', username='helios', domain='local', password=None, updatepw=None, prompt=None, quiet=None, helios=False):
    """authentication function"""
    global APIROOT
    global HEADER
    global AUTHENTICATED
    global HELIOSCLUSTERS
    global CONNECTEDHELIOSCLUSTERS

    if helios is True:
        vip = 'helios.cohesity.com'
    pwd = password
    HEADER = {'accept': 'application/json', 'content-type': 'application/json'}
    APIROOT = 'https://' + vip + '/irisservices/api/v1'
    if vip == 'helios.cohesity.com':
        HEADER = {'accept': 'application/json', 'content-type': 'application/json', 'apiKey': pwd}
        URL = 'https://helios.cohesity.com/mcm/clusters/connectionStatus'
        try:
            HELIOSCLUSTERS = (requests.get(URL, headers=HEADER, verify=False)).json()
            CONNECTEDHELIOSCLUSTERS = [cluster for cluster in HELIOSCLUSTERS if cluster['connectedToCluster'] is True]
            AUTHENTICATED = True
            if(quiet is None):
                print("Connected!")
        except requests.exceptions.RequestException as e:
            AUTHENTICATED = False
            if quiet is None:
                print(e)
    else:
        creds = json.dumps({"domain": domain, "password": pwd, "username": username})

        url = APIROOT + '/public/accessTokens'
        try:
            response = requests.post(url, data=creds, headers=HEADER, verify=False)
            if response != '':
                if response.status_code == 201:
                    accessToken = response.json()['accessToken']
                    tokenType = response.json()['tokenType']
                    HEADER = {'accept': 'application/json',
                              'content-type': 'application/json',
                              'authorization': tokenType + ' ' + accessToken}
                    AUTHENTICATED = True
                    if(quiet is None):
                        print("Connected!")
                else:
                    print(response.json()['message'])
        except requests.exceptions.RequestException as e:
            AUTHENTICATED = False
            if quiet is None:
                print(e)


def apiconnected():
    return AUTHENTICATED


def apidrop():
    global AUTHENTICATED
    AUTHENTICATED = False


def heliosCluster(clusterName=None, verbose=False):
    global HEADER
    if clusterName is not None:
        if isinstance(clusterName, basestring) is not True:
            clusterName = clusterName['name']
        accessCluster = [cluster for cluster in CONNECTEDHELIOSCLUSTERS if cluster['name'].lower() == clusterName.lower()]
        if not accessCluster:
            print('Cluster %s not connected to Helios' % clusterName)
        else:
            HEADER['accessClusterId'] = str(accessCluster[0]['clusterId'])
            if verbose is True:
                print('Using %s' % clusterName)
    else:
        print("\n{0:<20}{1:<36}{2}".format('ClusterID', 'SoftwareVersion', "ClusterName"))
        print("{0:<20}{1:<36}{2}".format('---------', '---------------', "-----------"))
        for cluster in sorted(CONNECTEDHELIOSCLUSTERS, key=lambda cluster: cluster['name'].lower()):
            print("{0:<20}{1:<36}{2}".format(cluster['clusterId'], cluster['softwareVersion'], cluster['name']))


def heliosClusters():
    return sorted(CONNECTEDHELIOSCLUSTERS, key=lambda cluster: cluster['name'].lower())


### api call function
def api(method, uri, data=None, quiet=None):
    """api call function"""
    if AUTHENTICATED is False:
        print('Not Connected')
        return None
    response = ''
    if uri[0] != '/':
        uri = '/public/' + uri
    if method in APIMETHODS:
        try:
            if method == 'get':
                response = requests.get(APIROOT + uri, headers=HEADER, verify=False)
            if method == 'post':
                response = requests.post(APIROOT + uri, headers=HEADER, json=data, verify=False)
            if method == 'put':
                response = requests.put(APIROOT + uri, headers=HEADER, json=data, verify=False)
            if method == 'delete':
                response = requests.delete(APIROOT + uri, headers=HEADER, json=data, verify=False)
        except requests.exceptions.RequestException as e:
            if quiet is None:
                print(e)

        if isinstance(response, bool):
            return ''
        if response != '':
            if response.status_code == 204:
                return ''
            if response.status_code == 404:
                if quiet is None:
                    print('Invalid api call: ' + uri)
                return None
            try:
                responsejson = response.json()
            except ValueError:
                return ''
            if isinstance(responsejson, bool):
                return ''
            if responsejson is not None:
                if 'errorCode' in responsejson:
                    if quiet is None:
                        if 'message' in responsejson:
                            print('\033[93m' + responsejson['errorCode'][1:] + ': ' + responsejson['message'] + '\033[0m')
                        else:
                            print(responsejson)
                    return None
                else:
                    return responsejson
    else:
        if quiet is None:
            print("invalid api method")


### convert usecs to date
def usecsToDate(uedate):
    """Convert Unix Epoc Microseconds to Date String"""
    uedate = int(uedate) / 1000000
    return datetime.fromtimestamp(uedate).strftime('%Y-%m-%d %H:%M:%S')


### convert date to usecs
def dateToUsecs(datestring):
    """Convert Date String to Unix Epoc Microseconds"""
    dt = datetime.strptime(datestring, "%Y-%m-%d %H:%M:%S")
    return int(time.mktime(dt.timetuple())) * 1000000


### convert date difference to usecs
def timeAgo(timedelta, timeunit):
    """Convert Date Difference to Unix Epoc Microseconds"""
    nowsecs = int(time.mktime(datetime.now().timetuple())) * 1000000
    secs = {'seconds': 1, 'sec': 1, 'secs': 1,
            'minutes': 60, 'min': 60, 'mins': 60,
            'hours': 3600, 'hour': 3600,
            'days': 86400, 'day': 86400,
            'weeks': 604800, 'week': 604800,
            'months': 2628000, 'month': 2628000,
            'years': 31536000, 'year': 31536000}
    age = int(timedelta) * int(secs[timeunit.lower()]) * 1000000
    return nowsecs - age


def dayDiff(newdate, olddate):
    """Return number of days between usec dates"""
    return int(round((newdate - olddate) / float(86400000000)))


# main ====================================================================================

### authenticate
apiauth(vip=vip, username=username, domain=domain, password=password)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

title = 'Missed SLAs on %s' % vip
missesRecorded = False
message = '<html><body style="font-family: Helvetica, Arial, sans-serif; font-size: 12px; background-color: #f1f3f6; color: #444444;">'
message += '<div style="background-color: #fff; width:fit-content; padding: 2px 6px 8px 6px; font-weight: 300; box-shadow: 1px 2px 4px #cccccc; border-radius: 4px;">'
message += '<p style="font-weight: bold;">Helios SLA Miss Report (%s)</p>' % now.date()
for hcluster in heliosClusters():
    heliosCluster(hcluster['name'])

    cluster = api('get', 'cluster')
    if cluster:
        printedClusterName = False
        # for each active job
        jobs = api('get', 'protectionJobs')
        if jobs:
            for job in jobs:
                if 'isDeleted' not in job and ('isActive' not in job or job['isActive'] is not False) and ('isPaused' not in job or job['isPaused'] is not True):
                    jobId = job['id']
                    jobName = job['name']
                    sla = job['incrementalProtectionSlaTimeMins']
                    slaUsecs = sla * 60000000
                    runs = api('get', 'protectionRuns?jobId=%s&numRuns=2' % jobId)
                    for run in runs:
                        # get backup run time
                        startTimeUsecs = run['backupRun']['stats']['startTimeUsecs']
                        status = run['backupRun']['status']
                        if status in finishedStates:
                            endTimeUsecs = run['backupRun']['stats']['endTimeUsecs']
                            runTimeUsecs = endTimeUsecs - startTimeUsecs
                        else:
                            runTimeUsecs = nowUsecs - startTimeUsecs
                        runTimeMinutes = int(round(runTimeUsecs / 60000000))
                        runTimeHours = runTimeMinutes / 60
                        # get replication time
                        replHours = 0
                        if 'copyRun' in run:
                            remoteRuns = [copyRun for copyRun in run['copyRun'] if copyRun['target']['type'] == 'kRemote']
                            for remoteRun in remoteRuns:
                                if 'stats' in remoteRun:
                                    if 'startTimeUsecs' in remoteRun['stats']:
                                        replStartTimeUsecs = remoteRun['stats']['startTimeUsecs']
                                        if 'endTimeUsecs' in remoteRun['stats']:
                                            replEndTimeUsecs = remoteRun['stats']['endTimeUsecs']
                                            replUsecs = replEndTimeUsecs - replStartTimeUsecs
                                        else:
                                            replUsecs = nowUsecs - replStartTimeUsecs
                                        replHours = int(round(replUsecs / 60000000)) / 60
                                        if replHours > maxreplicationhrs:
                                            break

                        if runTimeUsecs > slaUsecs or runTimeHours > maxbackuphrs or replHours > maxreplicationhrs:
                            if printedClusterName is False:
                                print(cluster['name'])
                                message += '<hr style="border: 1px solid #eee;"/><span style="font-weight: bold;">%s</span><br/>' % cluster['name'].upper()
                                printedClusterName = True
                            # replort sla miss
                            if status in finishedStates:
                                verb = 'ran'
                            else:
                                verb = 'has been running'
                            if (watch == 'all' or watch == 'backup') and (runTimeUsecs > slaUsecs or runTimeHours > maxbackuphrs):
                                messageline = '<span style="margin-left: 20px; font-weight: normal; color: #000;">%s:</span> <span style="font-weight: 300;">Backup %s for %s minutes (SLA: %s minutes)</span><br/>' % (jobName.upper(), verb, runTimeMinutes, sla)
                                message += messageline
                                print('    %s : (Missed Backup SLA) %s for %s minutes (SLA: %s minutes)' % (jobName.upper(), verb, runTimeMinutes, sla))
                                missesRecorded = True
                                # identify long running objects
                                if 'sourceBackupStatus' in run['backupRun']:
                                    for source in run['backupRun']['sourceBackupStatus']:
                                        if 'endTimeUsecs' in source['stats']:
                                            timeTakenUsecs = source['stats']['endTimeUsecs'] - startTimeUsecs
                                        elif 'timeTakenUsecs' in source['stats']:
                                            timeTakenUsecs = source['stats']['timeTakenUsecs']
                                        else:
                                            timeTakenUsecs = 0
                                        if timeTakenUsecs > slaUsecs:
                                            timeTakenMin = int(round(timeTakenUsecs / 60000000))
                                            print('            %s %s for %s minutes' % (source['source']['name'].upper(), verb, timeTakenMin))
                                            messageline = '<span style="margin-left: 60px;"><span style="color: #000; font-weight: normal;">%s</span> <span style="font-weight: 300;">%s for %s minutes</span></span><br/>' % (source['source']['name'].upper(), verb, timeTakenMin)
                                            message += messageline
                            # report long running replication
                            if (watch == 'all' or watch == 'replication') and replHours >= maxreplicationhrs:
                                print('    %s : (Missed Replication SLA) replication time: %s hours' % (jobName, replHours))
                                messageline = '<span style="margin-left: 20px; font-weight: normal; color: #000;">%s:</span> <span style="font-weight: 300;">Replication time: %s hours</span><br/>' % (jobName, replHours)
                                message += messageline
                                missesRecorded = True
                            break
    else:
        print('%-15s: (trouble accessing cluster)' % hcluster['name'])

if missesRecorded is False:
    print('No SLA misses recorded')
else:
    message += '</body></html>'
    # email report
    if mailserver is not None:
        print('\nSending report to %s...' % ', '.join(sendto))
        msg = email.message.Message()
        msg['Subject'] = title
        msg['From'] = sendfrom
        msg['To'] = ','.join(sendto)
        msg.add_header('Content-Type', 'text/html')
        msg.set_payload(message)
        smtpserver = smtplib.SMTP(mailserver, mailport)
        smtpserver.sendmail(sendfrom, sendto, msg.as_string())
        smtpserver.quit()
