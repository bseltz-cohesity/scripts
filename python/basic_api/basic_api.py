#!/usr/bin/env python

# =====================================
#  Python Module for Basic APIs
#  Version 2023.03.19 - Brian Seltzer
# =====================================
#
#  2022.03.19 - initial release
#
# =====================================

from datetime import datetime
import time
import requests
import getpass
import urllib3
import base64
import os
from os.path import expanduser

# ignore unsigned certificates ============================================================================
import requests.packages.urllib3
requests.packages.urllib3.disable_warnings()
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

__all__ = ['bapiauth',
           'bapi',
           'usecsToDate',
           'usecsToDateTime',
           'dateToUsecs']

# initialization ==========================================================================================

BASIC_API = {
    'base_url': '',
    'headers': {'accept': 'application/json', 'content-type': 'application/json'}
}

CONFIGDIR = expanduser("~") + '/.basic-api'
SCRIPTDIR = os.path.dirname(os.path.realpath(__file__))


# authentication function =================================================================================

def bapiauth(endpoint, username, password=None):
    password = __getpassword(endpoint=endpoint, username=username, password=password)
    authString = '%s:%s' % (username, password)
    encodedPassword = base64.b64encode(authString.encode('utf-8')).decode('utf-8')
    BASIC_API['headers']['Authorization'] = "Basic %s" % encodedPassword
    BASIC_API['base_url'] = 'https://%s' % endpoint


# api call function =======================================================================================

def bapi(method, uri, data=None):
    url = BASIC_API['base_url'] + uri
    responsejson = None
    try:
        if method == 'get':
            response = requests.get(url, headers=BASIC_API['headers'], verify=False)
        if method == 'post':
            response = requests.post(url, headers=BASIC_API['headers'], json=data, verify=False)
        if method == 'put':
            response = requests.put(url, headers=BASIC_API['headers'], json=data, verify=False)
        if method == 'delete':
            response = requests.delete(url, headers=BASIC_API['headers'], json=data, verify=False)
        try:
            responsejson = response.json()
        except ValueError:
            pass
        if response.status_code != 200:
            print('Error (%s) %s' % (response.status_code, response.reason))
            return None
        if responsejson is not None:
            return responsejson
    except requests.exceptions.RequestException as e:
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
