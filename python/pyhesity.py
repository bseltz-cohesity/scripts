#!/usr/bin/env python
"""Cohesity Python REST API Wrapper Module - 2021.12.11"""

##########################################################################################
# Change Log
# ==========
#
# 2020.05.29 - added re-prompt for bad password, debug log, password storage changes
# 2020.06.04 - bumping version (no reason)
# 2020.06.16 - removed ansi codes from error message (Windows didn't display them correctly)
# 2020.07.10 - added support for tenant impersonation
# 2020.09.09 - fixed invalid password loop for PWFILE
# 2020.10.01 - added noretry for password checking
# 2021.02.16 - added V2 API support
# 2021.04.04 - added usecsToDateTime and fixed dateToUsecs to support datetime object as input
# 2021.04.08 - added support for readonly home dir
# 2021.04.20 - added error return from api function
# 2021.09.25 - added support for DMaaS
# 2021.10.13 - modified setpwd function
# 2021.11.10 - added setContext and getContext functions
# 2021.11.15 - added dateToString function, usecsToDate formatting, Helios Reporting v2, Helio On Prem
# 2021.11.18 - added support for multifactor authentication
# 2021.12.07 - added support for email multifactor authentication
# 2021.12.11 - dateToUsecs defaults to now, added getDate()
#
##########################################################################################
# Install Notes
# =============
#
# Requires module: requests
# sudo easy_install requests
#         - or -
# sudo yum install python-requests
#
##########################################################################################

from datetime import datetime
import time
import json
import requests
import getpass
import base64
import os
import urllib3
from os.path import expanduser

### ignore unsigned certificates
import requests.packages.urllib3

requests.packages.urllib3.disable_warnings()

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

__all__ = ['apiauth',
           'api',
           'usecsToDate',
           'usecsToDateTime',
           'dateToUsecs',
           'dateToString',
           'timeAgo',
           'dayDiff',
           'display',
           'fileDownload',
           'apiconnected',
           'apidrop',
           'pw',
           'storepw',
           'setpwd',
           'showProps',
           'storePasswordFromInput',
           'heliosCluster',
           'heliosClusters',
           'getContext',
           'setContext',
           'getDate']

COHESITY_API = {
    'APIROOT': '',
    'APIROOTv2': '',
    'HEADER': {},
    'AUTHENTICATED': False
}

APIMETHODS = ['get', 'post', 'put', 'delete']
CONFIGDIR = expanduser("~") + '/.pyhesity'
SCRIPTDIR = os.path.dirname(os.path.realpath(__file__))
PWFILE = os.path.join(SCRIPTDIR, 'YWRtaW4')
LOGFILE = os.path.join(SCRIPTDIR, 'pyhesity-debug.log')


### authentication
def apiauth(vip='helios.cohesity.com', username='helios', domain='local', password=None, updatepw=None, prompt=None, quiet=None, helios=False, useApiKey=False, tenantId=None, noretry=False, regionid=None, mfaType='Totp', mfaCode=None, emailMfaCode=False):
    """authentication function"""
    global COHESITY_API
    global HELIOSCLUSTERS
    global CONNECTEDHELIOSCLUSTERS

    COHESITY_API['APIROOTMCM'] = 'https://%s/mcm/' % vip
    COHESITY_API['APIROOTMCMv2'] = 'https://%s/v2/mcm/' % vip
    COHESITY_API['APIROOTREPORTINGv2'] = 'https://%s/heliosreporting/api/v1/public/' % vip

    pwd = password
    if password is None:
        pwd = __getpassword(vip, username, password, domain, updatepw, prompt)
    COHESITY_API['HEADER'] = {'accept': 'application/json', 'content-type': 'application/json'}
    COHESITY_API['APIROOT'] = 'https://' + vip + '/irisservices/api/v1'
    COHESITY_API['APIROOTv2'] = 'https://' + vip + '/v2/'
    if vip == 'helios.cohesity.com' or helios is not False:
        COHESITY_API['HEADER'] = {'accept': 'application/json', 'content-type': 'application/json', 'apiKey': pwd}
        if regionid is not None:
            COHESITY_API['HEADER']['regionid'] = regionid
        URL = COHESITY_API['APIROOTMCM'] + 'clusters/connectionStatus'
        try:
            HELIOSCLUSTERS = (requests.get(URL, headers=COHESITY_API['HEADER'], verify=False)).json()
            if HELIOSCLUSTERS is not None and 'message' in HELIOSCLUSTERS:
                print(HELIOSCLUSTERS['message'])
                COHESITY_API['AUTHENTICATED'] = False
                return None
            if HELIOSCLUSTERS is not None and 'errorCode' not in HELIOSCLUSTERS:
                CONNECTEDHELIOSCLUSTERS = [cluster for cluster in HELIOSCLUSTERS if cluster['connectedToCluster'] is True]
                COHESITY_API['AUTHENTICATED'] = True
                if(quiet is None):
                    print("Connected!")
            else:
                URL = COHESITY_API['APIROOTMCMv2'] + 'dms/regions'
                REGIONS = (requests.get(URL, headers=COHESITY_API['HEADER'], verify=False)).json()
                if REGIONS is not None and 'message' in REGIONS:
                    print(REGIONS['message'])
                    COHESITY_API['AUTHENTICATED'] = False
                    return None
                if REGIONS is not None and 'errorCode' not in REGIONS:
                    COHESITY_API['AUTHENTICATED'] = True
                    if(quiet is None):
                        print("Connected!")
        except requests.exceptions.RequestException as e:
            COHESITY_API['AUTHENTICATED'] = False
            if quiet is None:
                __writelog(e)
                print(e)
    elif useApiKey is True:
        COHESITY_API['HEADER'] = {'accept': 'application/json', 'content-type': 'application/json', 'apiKey': pwd}
        if tenantId is not None:
            COHESITY_API['HEADER']['x-impersonate-tenant-id'] = '%s/' % tenantId
        COHESITY_API['AUTHENTICATED'] = True
        cluster = api('get', 'cluster')
        if cluster is not None:
            if(quiet is None):
                print("Connected!")
        else:
            COHESITY_API['AUTHENTICATED'] = False
    else:
        creds = json.dumps({"domain": domain, "password": pwd, "username": username, "otpType": mfaType, "otpCode": mfaCode})
        emailcreds = json.dumps({"domain": domain, "password": pwd, "username": username})

        url = COHESITY_API['APIROOT'] + '/public/accessTokens'
        try:
            if emailMfaCode is True:
                emailurl = COHESITY_API['APIROOTv2'] + 'email-otp'
                response = requests.post(emailurl, data=emailcreds, headers=COHESITY_API['HEADER'], verify=False)
                mfaCode = getpass.getpass("Enter emailed MFA code: ")
                creds = json.dumps({"domain": domain, "password": pwd, "username": username, "otpType": 'Email', "otpCode": mfaCode})

            response = requests.post(url, data=creds, headers=COHESITY_API['HEADER'], verify=False)
            if response != '':
                if response.status_code == 201:
                    accessToken = response.json()['accessToken']
                    tokenType = response.json()['tokenType']
                    COHESITY_API['HEADER'] = {'accept': 'application/json',
                                              'content-type': 'application/json',
                                              'authorization': tokenType + ' ' + accessToken}
                    if tenantId is not None:
                        COHESITY_API['HEADER']['x-impersonate-tenant-id'] = '%s/' % tenantId
                    COHESITY_API['AUTHENTICATED'] = True
                    if(quiet is None):
                        print("Connected!")
                else:
                    __writelog(response.json()['message'])
                    if quiet is None:
                        print(response.json()['message'])
                    if 'invalid username' in response.json()['message'].lower():
                        if noretry is False:
                            apiauth(vip=vip, username=username, domain=domain, updatepw=True, prompt=prompt, helios=helios, useApiKey=useApiKey)

        except requests.exceptions.RequestException as e:
            __writelog(e)
            COHESITY_API['AUTHENTICATED'] = False
            if quiet is None:
                print(e)


def apiconnected():
    return COHESITY_API['AUTHENTICATED']


def apidrop():
    global COHESITY_API
    COHESITY_API['AUTHENTICATED'] = False


def heliosCluster(clusterName=None, verbose=False):
    global COHESITY_API
    if clusterName is not None:
        if isinstance(clusterName, dict) is True:
            clusterName = clusterName['name']
        accessCluster = [cluster for cluster in CONNECTEDHELIOSCLUSTERS if cluster['name'].lower() == clusterName.lower()]
        if not accessCluster:
            print('Cluster %s not connected to Helios' % clusterName)
        else:
            COHESITY_API['HEADER']['accessClusterId'] = str(accessCluster[0]['clusterId'])
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
def api(method, uri, data=None, quiet=None, mcm=None, mcmv2=None, v=1, reportingv2=None):
    """api call function"""
    if COHESITY_API['AUTHENTICATED'] is False:
        print('Not Connected')
        return None
    response = ''
    if mcm is not None:
        url = COHESITY_API['APIROOTMCM'] + uri
    elif mcmv2 is not None:
        url = COHESITY_API['APIROOTMCMv2'] + uri
    elif reportingv2 is not None:
        url = COHESITY_API['APIROOTREPORTINGv2'] + uri
    else:
        if v == 2:
            url = COHESITY_API['APIROOTv2'] + uri
        else:
            if uri[0] != '/':
                uri = '/public/' + uri
            url = COHESITY_API['APIROOT'] + uri

    if method in APIMETHODS:
        try:
            if method == 'get':
                response = requests.get(url, headers=COHESITY_API['HEADER'], verify=False)
            if method == 'post':
                response = requests.post(url, headers=COHESITY_API['HEADER'], json=data, verify=False)
            if method == 'put':
                response = requests.put(url, headers=COHESITY_API['HEADER'], json=data, verify=False)
            if method == 'delete':
                response = requests.delete(url, headers=COHESITY_API['HEADER'], json=data, verify=False)
        except requests.exceptions.RequestException as e:
            __writelog(e)
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
                            print(responsejson['errorCode'][1:] + ': ' + responsejson['message'])
                            return('error')
                        else:
                            print(responsejson)
                            return('error')
                    return None
                else:
                    return responsejson
    else:
        if quiet is None:
            print("invalid api method")


### convert usecs to date string
def usecsToDate(uedate, fmt='%Y-%m-%d %H:%M:%S'):
    """Convert Unix Epoc Microseconds to Date String"""
    uedate = int(uedate) / 1000000
    return datetime.fromtimestamp(uedate).strftime(fmt)


### convert usecs to datetime object
def usecsToDateTime(uedate):
    """Convert Unix Epoc Microseconds to Date String"""
    uedate = int(uedate) / 1000000
    return datetime.fromtimestamp(uedate)


### convert date to usecs
def dateToUsecs(dt=datetime.now()):
    """Convert Date String to Unix Epoc Microseconds"""
    if isinstance(dt, str):
        dt = datetime.strptime(dt, "%Y-%m-%d %H:%M:%S")
    return int(time.mktime(dt.timetuple())) * 1000000


### convert date to string
def dateToString(dt, fmt='%Y-%m-%d %H:%M:%S'):
    """Convert date to date string"""
    return dt.strftime(fmt)


### get current date
def getDate():
    """get current date time"""
    return datetime.now()


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


### get/store password for future runs
def __getpassword(vip, username, password, domain, updatepw, prompt):
    """get/set stored password"""
    if password is not None:
        return password
    if prompt is not None:
        pwd = getpass.getpass("Enter your password: ")
        return pwd
    if os.path.exists(PWFILE):
        f = open(PWFILE, 'r')
        pwdlist = [e.strip() for e in f.readlines() if e.strip() != '']
        f.close()
        for pwditem in pwdlist:
            v, d, u, opwd = pwditem.split(":", 4)
            if v.lower() == vip.lower() and d.lower() == domain.lower() and u.lower() == username.lower():
                if updatepw is not None:
                    setpwd(v=vip, u=username, d=domain)
                    return pw(vip, username, domain)
                else:
                    return base64.b64decode(opwd.encode('utf-8')).decode('utf-8')
    if domain.lower() == 'local':
        pwpath = os.path.join(CONFIGDIR, vip + '-' + username)
    else:
        pwpath = os.path.join(CONFIGDIR, domain + '-' + username)
    if(updatepw is not None):
        if(os.path.isfile(pwpath) is True):
            os.remove(pwpath)
    try:
        pwdfile = open(pwpath, 'r')
        opwd = pwdfile.read()
        pwd = base64.b64decode(opwd.encode('utf-8')).decode('utf-8')
        pwdfile.close()
        return pwd
    except Exception:
        __writelog('prompting for password...')
        pwd = getpass.getpass("Enter your password: ")
        try:
            pwdfile = open(pwpath, 'w')
            opwd = base64.b64encode(pwd.encode('utf-8')).decode('utf-8')
            pwdfile.write(opwd)
            pwdfile.close()
            return pwd
        except Exception:
            print('error storing password')
            return pwd


# store password in PWFILE
def setpwd(v='helios.cohesity.com', u='helios', d='local', password=None):
    if password is None:
        pwd = getpass.getpass("Enter password for %s/%s at %s: " % (d, u, v))
    else:
        pwd = password
    opwd = base64.b64encode(pwd.encode('utf-8')).decode('utf-8')
    if os.path.exists(PWFILE):
        f = open(PWFILE, 'r')
        pwdlist = [e.strip() for e in f.readlines() if e.strip() != '']
        f.close()
    else:
        pwdlist = []
    f = open(PWFILE, 'w')
    foundPwd = False
    for pwditem in pwdlist:
        vip, domain, username, cpwd = pwditem.split(":", 4)
        if v.lower() == vip.lower() and d.lower() == domain.lower() and u.lower() == username.lower():
            f.write('%s:%s:%s:%s\n' % (v, d, u, opwd))
            foundPwd = True
        else:
            f.write('%s\n' % pwditem)
    if foundPwd is False:
        f.write('%s:%s:%s:%s\n' % (v, d, u, opwd))
    f.close()


### pwstore for alternate infrastructure
def pw(vip, username, domain='local', password=None, updatepw=None, prompt=None):
    return __getpassword(vip, username, password, domain, updatepw, prompt)


def storepw(vip, username, domain='local', password=None, updatepw=True, prompt=None):
    pwd1 = '1'
    pwd2 = '2'
    while(pwd1 != pwd2):
        pwd1 = __getpassword(vip, username, password, domain, updatepw, prompt)
        pwd2 = getpass.getpass("Re-enter your password: ")
        if(pwd1 != pwd2):
            print('Passwords do not match! Please re-enter...')


### store password from input
def storePasswordFromInput(vip, username, password, domain):
    if domain.lower() == 'local':
        pwpath = os.path.join(CONFIGDIR, vip + '-' + username)
    else:
        pwpath = os.path.join(CONFIGDIR, domain + '-' + username)
    try:
        pwdfile = open(pwpath, 'w')
        opwd = base64.b64encode(password.encode('utf-8')).decode('utf-8')
        pwdfile.write(opwd)
        pwdfile.close()
    except Exception:
        print('error trying to store password')


### debug log
def __writelog(logmessage):
    debuglog = open(LOGFILE, 'a')
    debuglog.write('%s:\n' % datetime.now().strftime("%Y-%m-%d-%H-%M-%S"))
    debuglog.write('%s\n' % logmessage)
    debuglog.close()


### display json/dictionary as formatted text
def display(myjson):
    """prettyprint dictionary"""
    if(isinstance(myjson, list)):
        # handle list of results
        for result in myjson:
            print(json.dumps(result, sort_keys=True, indent=4, separators=(', ', ': ')))
    else:
        # or handle single result
        print(json.dumps(myjson, sort_keys=True, indent=4, separators=(', ', ': ')))


def fileDownload(uri, fileName):
    """download file"""
    if COHESITY_API['AUTHENTICATED'] is False:
        return "Not Connected"
    if uri[0] != '/':
        uri = '/public/' + uri
    response = requests.get(COHESITY_API['APIROOT'] + uri, headers=COHESITY_API['HEADER'], verify=False, stream=True)
    f = open(fileName, 'wb')
    for chunk in response.iter_content(chunk_size=1048576):
        if chunk:
            f.write(chunk)
    f.close()


def showProps(obj, parent='myobject', search=None):
    if isinstance(obj, dict):
        for key in sorted(obj):  # obj.keys():
            showProps(obj[key], "%s['%s']" % (parent, key), search)
    elif isinstance(obj, list):
        x = 0
        for item in obj:
            showProps(obj[x], "%s[%s]" % (parent, x), search)
            x = x + 1
    else:
        if search is not None:
            if search.lower() in parent.lower():
                print("%s = %s" % (parent, obj))
        else:
            print("%s = %s" % (parent, obj))


def getContext():
    return COHESITY_API.copy()


def setContext(context):
    global COHESITY_API
    if isinstance(context, dict) and 'HEADER' in context and 'APIROOT' in context and 'APIROOTv2' in context:
        COHESITY_API = context.copy()
    else:
        print('Invalid context')


### create CONFIGDIR if it doesn't exist
if os.path.isdir(CONFIGDIR) is False:
    try:
        os.mkdir(CONFIGDIR)
    except Exception:
        pass

##########################################################################################
# Old Change Log
# ==============
#
# 1.1 - added encrypted password storage - August 2017
# 1.2 - added date functions and private api access - April 2018
# 1.3 - simplified password encryption (weak!) to remove pycrypto dependency - April 2018
# 1.4 - improved error handling, added display function - May 2018
# 1.5 - added no content return - May 2018
# 1.6 - added dayDiff function - May 2018
# 1.7 - added password update feature - July 2018
# 1.8 - added support for None JSON returned - Jan 2019
# 1.9 - supressed HTTPS warning in Linux and PEP8 compliance - Feb 2019
# 1.9.1 - added support for interactive password prompt - Mar 2019
# 2.0 - python 3 compatibility - Mar 2019
# 2.0.1 - fixed date functions for pythion 3 - Mar 2019
# 2.0.2 - added file download - Jun 2019
# 2.0.3 - added silent error handling, apdrop(), apiconnected() - Jun 2019
# 2.0.4 - added pw and storepw - Aug 2019
# 2.0.5 - added showProps - Nov 2019
# 2.0.6 - handle another None return condition - Dec 2019
# 2.0.7 - added storePasswordFromInput function - Feb 2020
# 2.0.8 - added helios support - Mar 2020
# 2.0.9 - helios and error handling changes - Mar 2020
# 2.1.0 - added support for Iris API Key - May 2020
# 2.1.1 - added support for PWFILE - May 2020
##########################################################################################
