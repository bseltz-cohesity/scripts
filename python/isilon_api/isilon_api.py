#!/usr/bin/env python

# =====================================
#  Python Module for Isilon APIs
#  Version 2024.06.05 - Brian Seltzer
# =====================================
#
#  2024.06.05 - initial release
#
# =====================================

from datetime import datetime
import time
import requests
import getpass
import urllib3
import base64
import os
import json
from os.path import expanduser

# ignore unsigned certificates ============================================================================
import requests.packages.urllib3
requests.packages.urllib3.disable_warnings()
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

__all__ = ['isilonauth',
           'isilonapi',
           'usecsToDate',
           'usecsToDateTime',
           'dateToUsecs',
           'display']

# initialization ==========================================================================================

ISILON_API = {
    'base_url': '',
    'headers': {'accept': 'application/json', 'content-type': 'application/json'},
    'SESSION': requests.Session()
}

CONFIGDIR = expanduser("~") + '/.isilon-api'
SCRIPTDIR = os.path.dirname(os.path.realpath(__file__))


# authentication function =================================================================================

def isilonauth(endpoint, username, password=None):
    password = __getpassword(endpoint=endpoint, username=username, password=password)
    creds = json.dumps({"password": password,
                        "username": username,
                        "services": [
                            "platform",
                            "namespace",
                            "remote-service"
                        ]})

    url = 'https://%s/session/1/session' % endpoint
    response = ISILON_API['SESSION'].post(url, data=creds, headers=ISILON_API['headers'], verify=False)
    ISILON_API['base_url'] = 'https://%s' % endpoint
    ISILON_API['headers']['isisessid'] = ISILON_API['SESSION'].cookies.get('isisessid')
    ISILON_API['headers']['X-CSRF-Token'] = ISILON_API['SESSION'].cookies.get('isicsrf')
    ISILON_API['headers']['referer'] = ISILON_API['base_url']
    ISILON_API

# api call function =======================================================================================

def isilonapi(method, uri, data=None):
    url = ISILON_API['base_url'] + uri
    responsejson = None
    try:
        if method == 'get':
            response = ISILON_API['SESSION'].get(url, headers=ISILON_API['headers'], verify=False)
        if method == 'post':
            response = ISILON_API['SESSION'].post(url, headers=ISILON_API['headers'], json=data, verify=False)
        if method == 'put':
            response = ISILON_API['SESSION'].put(url, headers=ISILON_API['headers'], json=data, verify=False)
        if method == 'delete':
            response = ISILON_API['SESSION'].delete(url, headers=ISILON_API['headers'], json=data, verify=False)
        try:
            responsejson = response.json()
        except ValueError:
            pass
        if response.status_code not in [200, 201, 204]:
            print('Error (%s) %s' % (response.status_code, response.reason))
        #     return None
        if responsejson is not None:
            return responsejson
    except requests.exceptions.RequestException as e:
        if str(e) != "('Connection aborted.', RemoteDisconnected('Remote end closed connection without response'))":
            print(e)
    return None


# date functions ==========================================================================================

def usecsToDate(uedate, fmt='%Y-%m-%d %H:%M:%S'):
    """Convert Unix Epoc Microseconds to Date String"""
    uedate = int(uedate) / 1000000
    return datetime.fromtimestamp(uedate).strftime(fmt)


def usecsToDateTime(uedate):
    """Convert Unix Epoc Microseconds to Date String"""
    uedate = int(uedate) / 1000000
    return datetime.fromtimestamp(uedate)


def dateToUsecs(dt=datetime.now()):
    """Convert Date String to Unix Epoc Microseconds"""
    if isinstance(dt, str):
        dt = datetime.strptime(dt, "%Y-%m-%d %H:%M:%S")
    return int(time.mktime(dt.timetuple())) * 1000000


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


def display(myjson):
    """prettyprint dictionary"""
    if isinstance(myjson, list):
        # handle list of results
        for result in myjson:
            print(json.dumps(result, sort_keys=True, indent=4, separators=(', ', ': ')))
    else:
        # or handle single result
        print(json.dumps(myjson, sort_keys=True, indent=4, separators=(', ', ': ')))


# password storage function ===============================================================================

def __getpassword(endpoint, username, password):
    """get/set stored password"""
    if ':' in endpoint:
        endpoint = endpoint.replace(':', '--')
    pwpath = os.path.join(CONFIGDIR, endpoint + '-' + username)
    if password is not None:
        pwd = password
        try:
            pwdfile = open(pwpath, 'w')
            opwd = base64.b64encode(pwd.encode('utf-8')).decode('utf-8')
            pwdfile.write(opwd)
            pwdfile.close()
            return pwd
        except Exception:
            print('error storing password')
            return pwd
    try:
        pwdfile = open(pwpath, 'r')
        opwd = pwdfile.read()
        pwd = base64.b64decode(opwd.encode('utf-8')).decode('utf-8')
        pwdfile.close()
        return pwd
    except Exception:
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


if os.path.isdir(CONFIGDIR) is False:
    try:
        os.mkdir(CONFIGDIR)
    except Exception:
        pass
