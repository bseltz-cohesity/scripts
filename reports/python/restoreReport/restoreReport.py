#!/usr/bin/env python
"""Restore Report for Python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime, timedelta
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', action='append', type=str)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-s', '--startdate', type=str, default='')
parser.add_argument('-e', '--enddate', type=str, default='')
parser.add_argument('-t', '--thismonth', action='store_true')
parser.add_argument('-l', '--lastmonth', action='store_true')
parser.add_argument('-y', '--days', type=int, default=31)
parser.add_argument('-f', '--folder', type=str, default='.')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
startdate = args.startdate
enddate = args.enddate
thismonth = args.thismonth
lastmonth = args.lastmonth
days = args.days
folder = args.folder

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# date range calc
now = datetime.now()
dateString = dateToString(now, "%Y-%m-%d")

thisCalendarMonth = now.replace(day=1, hour=0, minute=0, second=0)
endofLastMonth = thisCalendarMonth - timedelta(seconds=1)
lastCalendarMonth = endofLastMonth.replace(day=1, hour=0, minute=0, second=0)

if startdate != '' and enddate != '':
    uStart = dateToUsecs(startdate)
    uEnd = dateToUsecs(enddate)
elif thismonth:
    uStart = dateToUsecs(thisCalendarMonth)
    uEnd = dateToUsecs(now)
elif lastmonth:
    uStart = dateToUsecs(lastCalendarMonth)
    uEnd = dateToUsecs(endofLastMonth)
else:
    uStart = timeAgo(days, 'days')
    uEnd = dateToUsecs(now)

start = usecsToDate(uStart, '%Y-%m-%d')
end = usecsToDate(uEnd, '%Y-%m-%d')

if mcm or vip.lower() == 'helios.cohesity.com':
    if clusternames is None or len(clusternames) == 0:
        clusternames = [c['name'] for c in heliosClusters()]
else:
    cluster = api('get', 'cluster')
    clusternames = [cluster['name']]

print('Collecting report data...')

title = 'Restore Report (%s - %s)' % (start, end)

filepart = ''
if len(clusternames) == 1:
    filepart = '-%s' % clusternames[0]

htmlfileName = '%s/restoreReport%s-%s-%s.html' % (folder, filepart, start, end)
csvfileName = '%s/restoreReport%s-%s-%s.csv' % (folder, filepart, start, end)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"Cluster","Date","Task","Object","Type","Target","Status","Duration (Min)","User"\n')

html = '''<html>
<head>
    <style>
        p {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        span {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        table {
            font-family: Arial, Helvetica, sans-serif;
            color: #333333;
            font-size: 0.75em;
            border-collapse: collapse;
            width: 100%;
        }
        tr {
            border: 1px solid #F1F1F1;
        }
        td,
        th {
            width: 33%;
            text-align: left;
            padding: 6px;
            white-space:nowrap;
        }
        tr:nth-child(even) {
            background-color: #F1F1F1;
        }
    </style>
</head>
<body>
    <div style="margin:15px;">
            <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAALQAAAAaCAYAAAAe23
            asAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAXEgAAFxIBZ5/SUgAAAVlpVFh0WE1MOmNvbS5hZG9i
            ZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9Il
            hNUCBDb3JlIDUuNC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9y
            Zy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZG
            Y6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFkb2JlLmNvbS90
            aWZmLzEuMC8iPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW
            9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4K
            TMInWQAAF3RJREFUeAHdnAmUlcWVx7/v7d10gwu4x4VxGcUlMYoaTQLS0GLUODO2TsYxaDxBBT
            GuMS6ZPM9JYjSajDFAglscHbd3NC5HUewWFPctTFwSzVGMioMgUZZe3vrN71/vu4/Xj/foB84o
            Zy7eV1W3bt26detf9dW3tL63LiURZUNxMhaLjSc/Ad4P/gK8HRwPgmCp7/vvkn8BfrBQKCwgFc
            XhIlxSoQFJpwAHqqePr5B8DXt7Y1f2W2G1/5jyW6QvFIvFBaTvwSL5mIdr+4giU98j4/H4P5FK
            zy+VSstofyd56fuw65e0HpmNrUIbKsex8R427iavthG4hN8T8Xln6nKRSET9IG6aAtpEaFPA7v
            20WgkP8m3GQ5OT1x45183F1BePbo2u7t/XK/q7ojfC9yPSbUh+pBQERS+G/j2zOue9FwQerjp1
            +e9Ho9F/pPsdybs45vN5je1Dp0H8qe+ifnPKOVjj/TSkoT6YzWbfSqVSoxlvJ8ZicJH5TRHHew
            cGBt6mLFzIn6HIzRE+HsOgdoUHaJAglktktJoqYGYyv0tn06kUkNchjOyCUPx1+Hyc6iH9EcB+
            ilShM2CQHUQJSgqSh0PHYudssrLh0Z+SQUS9K2N/GfV3k16twCCUfQesqgay3Y/dcej+xuTYEN
            KegJfACprrn7QemY0ObMwyBWz0kn8SXgrLKcXud+hsJx9JK4hB3hRZG8WBSb6PRurbAbjrrq7E
            tUdmstPmj2sLSomz/ZXZExjumERbzGE5DMu6/Ti4stoKgZfaLOGtWtonf+/MeF3EKqN4CTAj8f
            kG+h9hBvBhFT7cqjJzP4Y6jc2qP1Wq+GB7FEZ+yMI5kHIlrjIMZr5FciAs32rnFNEgaqHUDw4m
            kipmldhj95VqQLtgsoJ2oYObGIwDmRpAfbA6Exi0e4q0KgQM2ZBsgpiOLqL9z8hrp6wFtfpQmz
            aCNoc+NBAj9aFdW/bUTtFUWWCU/a1w+AwCcyJtLyQwBth6AZBMZPZWka8eq6sc4sdsCGBa6Gtg
            jV8k3+L4k2cMKqsf6SvVuJsljW0YbHZdO4E5c3wmd/q8iYd6Jf+mluHx3UrFwMv1FgJYcXedlp
            Pygq+I3FqjFTZzfYVcoVR6RkaP9zLqS3EVKRYajwAteynYxkvW6ale41a9zYc6U99K5bN1TrYy
            9mqZdAlR0Ebqdl7mL8P8HYPsX5D1w7J9ALj5Mbi5lLzsukVNWktus0EoezPDSm00w7CXZT5OtU
            mWkRwdjcXoXPJbwJoYWzEGYkROruAoCGKRHJBMq+dynGvHziXkZcOCYGDegfqHcWAMdSIBWX5U
            9yF5Ldngh9N2NjZG08f3UVK/1oe1MVDZ+CSXXjMUgqUCTAOB2lbbCLjEFQmi5Na/xrhBpPaMx8
            AUpF/rSqTHZHLTuydNDHxvbrItHh1Ylc/qApAcFktEYn4qKBmm6nSFJ8VcyRs2MumtXNK3YM7E
            7neBoM+/wFPEX3Ntqsdh47OYyR+NR6ARDVpsZVHltzr2hoVKpWXCMdpclNiMzmL+vk799rAWjO
            gSZHOZ06fIu13YSdf+2IahK/tViHeDtTlazC/D7gvqRJxPJpN7sHoeJT8ctlVpTv4Z2S3wUxhb
            goOoFrdi4OPg0ynvTJ3I2l2Mcytw7hfIFH23YEjbkT9EqtBKV4EzIC/Azm3Ye5Xzls6TUQCzHW
            kHfAq8JawAavHI3gXY+og+riSvSdHuaGQAqS6rr2bI9MxGbbliQwdD/FVZOtJ/Hn4amXbdCkDI
            NyK1LyQSiaf7+/u9rrsOiQLm/jO6O0YDqbsSrbFodk2+N5qIDAu0Q/cV7/GC0jw/iHzsRlxttV
            j0ShG/7EzgB5+835uK+PGF1SohmE1k47LUxhslpq8SW21Io2DF23QU53581pHl2+Q1d5oTte2G
            X6GunbR6LnxkUULljgfUCV8rkJ2FDZ3bhTH1oavBLPgAWJuX5jgPGwmnOfCnc/NpoVB9q/2T+H
            w5qfnpRRnA83AA98GFMK8bn3PDxo0Stb0m1Ff7XJh/vbYBV4DfhXU6A5neMpw8ula3pjyctjeF
            bav7CJAfFOoq2G4BYq+rSlf6WiA7hnq2osPiOol2B+0CJ4Y2LBYfItaOItIEJtFZXK2DL+e42o
            34GZceF3M7KW3P6Om869wXjwqm9UzqO+vJyUrfn/7IJBvnBlnXzl7VwMa+NX4vCX3PK2UsAqjI
            Nphyqf5vG22W1rQfag5lyRaNwKoYXxfaEBacH6TafUUCsOkrL9qSGL8TtukN06yOyeVqL+4aoH
            Q6ggNhrRQNWuBQfly4y5J1K0ZytTGWbhGd75GeD4u069yAbFK56BzTk4yJyKeEMgVZg1qC3v7s
            9g+Ql20bhNmXTH2s4nJyCmkaFklPlxtdHq9RCtnxplz6DH7ZdQb1gi92mdYOLR+bZW+fsS1RoB
            dMmz/xi4zqaM7Ksp3KZ4sDflA8fGbnvOfOebrLLTZVNCLO31E9EZn64pfjWiA60TTSbSDXrieq
            9V1zoXF5AEg79+DBl3deVSsGNpfVNqRvtl3KvE8nZm8jFxZsVz8PrHSEZbUXVlwdC+Aq9HeirK
            u7WxQMcDpPSBaH5bwa6HHH2Rp5NdFwCh0+gcwuCdXbv6kKVLIBLgtXszBW024x7R4NFVxdmD8z
            THtJXWDo8zjy78P1zkyhugOqQJ2jj8voY0/6OIGyHFZgDmKgx9CnHn3psqXLVT2yibW0no5kVm
            9pI716cjtmKC42QfX01pFlt1rmJjkoRcal2qKp7OpCNjU8nsyuyl05s6PnTT3t+OVXMmtO7zl8
            +0gkdphf9HS+CGhEGIMix5CPSn7+zd9MyCzBeF9X0BXtyoyOZLyM+bROnw0EBoR6/jsMACC3m9
            a0t37UzvI1KpWi6t2c4vzJ5A1nAqrwdi2sDVY3pioPMMfHhbqKk1jy37PRXU8qn51vMRQnoLgr
            AjmiSdTquhuA3EmqVaWden2Tq3YyGMH4HFKRWz2kqvM4n++OvSOUNwKU1wPQZylLtxEITV0Aca
            BnV/wRtiZT1lnMnb3wfwp5AVoDrUv4kORxn+oUCPlrEyeZkcapRVHZAayiyVQLWCQb9ey7ypqf
            QjrteekDXnKxItS7u0fMtM4PFL1IPHav9GeNX7BGZ2vfizzcMjyxm6sLH0XrGF/MgZFibOm07k
            mPszfNmulnBBLO5V1RnpgMBTCpGq1vrm1MllobpfVk1fW1ec1pHAwsZEfW+fciWDY0SX8PLn/K
            PJ9FXnMxijmeTSrqg3UV0P3TNAkg4dSNMYKiAU0I12SLZpYTp7i+AYZqDvACkyZSrMmRPTdIrg
            BfJa8VKeC6Mxr93kRe1GywNbAYoHyDtnaDoYGIxsK6GdGKFtX6HNDuw3KVt5pUwVTgallynbdF
            H5eTDfrV1UckP2SrGS69tleX4uR8JtPucoEXK+ZL2XxfsNYPP/KN9q1Tu/V/kltTGCj0cyzJ8m
            huIN9fGOC5czGWjG6TGhE/wYv4j0/v7rwam57AnA7SFieJNiVyixhgXoxTL8PCjvAQMMczALU2
            Lh1X55CMhA3MOmoKzEtVDVcwpMKXYJEJX6WDF8qiDfrVhAgg1eQmCUDvj4OSa4JbcOYtVt+r1Y
            pN5GVLuzmPVkuPYu+ksKym23EU2YMrxIsq1KE4wTmaNu/SdzupLTbnH/rOOVKqgyRXgQ9JD6lj
            Z5AIP9wh1YS02Zn8F/Bla1J3CbS6BqmPz28Aun5AXH60Fni9zhvfK0RikaQXKW5WaRtEHl+9dG
            AVj+SGux06GrpNohcpALxYGChm/ajf2rJl4txpPRN3mDXh0RPSfrrhlati+/PJKP7CYIE5OZX4
            /YG8Njx3LEX2M8C8D+VjYeFTpwdN0k3gJ6M8NGhsMSq3paEqyj++/yfyjXY66W0IOcBgf6ewkZ
            XfpLxqQwxVtwdwb+K3VreCIZt6haw+6gFagWjFh/8kHQRAlWtJscC2iZWpFExYJ7XYTWcCzqS9
            tXHyOvoSCfDxWCR2YaFUuLLrl4ekMt4zPBLz3gpbB4nWqDewqqTJXKQbQs7Qf5zRPfmQvo+yHV
            40KJbCLYi37q200VXq2MSwWCu7drZ3RdZvG5k6/oyeSW/OnjDvh+n542Lp8QvML1Q3GXJAZWEv
            InYX4NXPYV3NNb/7hkzi4pUitG8D5vMkgNw5vJwt//Ie1ddZVOQuSwDjo3LR/f5vBcD6sImv7q
            OquyGzzh8A/QmD0hGkDZbMR7YZsnoGDFTu8lZPoY5MNhUP7QjWvo7aOiK1G7RjrKNRFsimnI3T
            y2auRTLpdh8vVlqYXZ0vsMumeKEi7QunPjLpDsD85zIo576OTLwOnfnIpF2y/fkbk63xcYA6D6
            g9wH7pad0Tbk+P73n96PSXWx9Iv5Qfxi15+XZiHROfh8DNqTrmZHAVoO4k2wFrfssxKcfKjsMz
            kOsYprJ0BpEmrXYCKh0M0vx0hVpQfBZ9mMfWl3bzZllHGwVTba092fWS9GwRqO36WHopXQ0g9e
            UtX/6OW3Czx3c/S/ExXqqo5754KsrHO1736T2dY9lhGy5Kfcj06855i2cf/uh4wPw4O7XsDpB6
            MT96pvrwW9YYQFTclEiLW7utnk3LV129BVgbr+Il+hWb1kOkGlvt8Vb1boJ1E7QN7IDNTjeqaq
            erBaLabAzZ8cKBg8vGFhtjhDbOH64iOlfaijWZbvbqkYKhwOi+QGczBaN6EdsYDbjSV7B2gPeC
            rZ7sYCJW1ccT8OnO6H9FS5NT3cfghmWbBeKwOfycKhek38lXvq4LIpeyS0/kDWErZ+U18Zbo9t
            z2PTf9sUk3c2qfh+VlUT8oaVDRgP+iwfJrx89ddNIjk4bd0jmvlzcBZ2fXFJ6L8pqcM7VW5OHq
            4/4L39BNuddLFFgkmxrp/iqhm37uQS4gLr+lrLnSMOXty+zg55Ma2XxZ2aVSfA/eAzaw7Ulel3
            KdoxtOJnXNkNrjW/DXcDcye3+HnAufA1gzdkzHtQfQu2PPpsTJKH9gSjWp6vsIRhfpEliAXR/Y
            FMQ8O8U/Y/N28s2QxW4O/fyEBrpb1wQNRTYp8rHIp6LFNB8mpTsyL0ybP+m7APp6HuG15fuLK1
            Ec3rp5YgrfaUwpZMvuKwCKqz5cmtbdefasjkeu0YdNs8ZnFvF28bloMvrVQr8D9HYz5k/eAdC/
            P5RDm0I95+k7APXF4GYn/LG5uo28zmDrxY0mVzuXSHnR3pxjvljObvCvwFB9WXNgYydbFFpSvW
            hPHN69nG36V7a0WkWHlpNKWd+NvBHKGiXOFyot/bR69dpb8OWnwDoUy4b8kZ6jdFcmr2fHs8bP
            u4HvOE5ih861bpnk+2fP7/84t5onGf2lQinPU408QM7zaK+fHZzZC84Lnzm7hYRBvrmRSffuO8
            HlQEDY1MnioO/PLZa181X3RskGJhDrTCLSJdxdklgZpzhJ+TBuQA9FdRN1KtYKUodu8yB1xC7y
            dJi1RzLatr9l1WE6VJJAQfb1kP0bobINTs8wl8G6sohqg6DXtbaYZEdj0sKrZclVL7IrQLnU3K
            +10Q6tfDM82DIPWca8ngnSPDue3fHoraVSsHf/37I3g8u+ZHu8nbeHLXBczJd4cWQt8Ra6KXnz
            9czZvfIuWxxRXiaEIvD4AKrg5nZwZ5tcqTJvbIKVfOhlMzj0YuxsT7IjP0+jsbBbIQDmO8huoW
            4BMpskWzGIBpHq3c7JZfoo+N1cLvfHUMM5QVlfb3Uj64BtFZ7Dy7vrODP9BZmB1erC5pVEYBSY
            9ZD9QpIdYIHZXQ3w9zbyIvO1XKr65XWtgV++NhqLWrixkJq+ZM2S2ZUNs9Ns24peOu2Vgh+l/d
            fYqX87KaP4nHz2E50XsT8fzH67B5tBu5akz1d1nDniA6ty7/Kp1/XuKcgBC/Iznpg8qpgvfqlY
            4MStCAX+0g8O3XwJOZU2Zlw0+0xJn+bWPmJthI1BjjkAEKAfA4r7qRGwdEOkHeZuPms8DDD+ib
            xIwahdJerETRxA/jY2bsYRfZ12BYvhGuqWw+pDN0C/or6DvHZpPW5JcfOZIT04LGtFSrd2ZaoP
            B2b6mELenkGq3yR2F9PXLeRFzZxba+2XW679tXpL19YMnbP4aBxDAUf2NTal0lW+QjouTH3x7c
            jJ88fFe5ePKv371zL/TeXvKwo1Ge3oaS/tbJTyhfPYvbcZWF3Ipdpjidya/BMZP1PsmjmmLTP9
            tTWb2GO7mpF8uqICrz+PeYAz7a2A418pCtCamC0A57OA6GTqFUgFve4kAWDdff4cFuUA7iXIjg
            Ro+1N2gFcfyGTnH2DtZJLvh+x5Li8nsnBeCWUk6xJ6P0B6eVgj4GqBidS3/NJYbIck+7mQnqKI
            +srJBv0awK1RMOeAl7SQ3WI2YaM0Hb4N5EXKDD8WuTDL13o6dxf42L9U8Geq3crFPBP5f04CgY
            BR5M5yGqCxNzOaEIFkOOC8B3k3qS7rL6O3grTE7r0FC+BAeCpl7bIiTaj+HEZn5CudpLwDqZ88
            AJ+BrYPIbwdLVwHeh4XzXyycOeTvo/4tjiF6BBdlkY0iHRv2ocUh0u6uBae3nL9modwTlrVA7J
            xM9v+eai+LxOhgxnE0PW8Bu4U8hBcCsf5IVvcxq+BqUPszeiaPLsbyichAJNC1M8cyjsbJh8QN
            oa8yt4fxWDwyGuh+J56KfTM/UCD+3uq2kcl23ipeO7tz3kvVN4wNHttV7Jr9TSTdIL8ENAFXQF
            gN4CYDqAfJ6ymHDAlYulnUH4x2kOpDbL2lYS5Lm4d1JA5k2knaVWBiT8XWHcqHpDqmRHfevv6e
            rIf8CFjg1BWhDflppKcxuSvpQ48MBVgBw0AqPdlxN37o36oFQlk01KAFlI0la2tpxY5uXPBRZX
            fUIN+FX10VhSYzLIJvMu77UY/zJ1ie/gTrjO7Ow4peca5X5C/D436BU3XEPTvWB6MhheWAB5ix
            aEsklYjpVXmezSjw20e1tK9Znu2ZNWHeWVIPv7izq5pENp5GqXTWR7Xt1qe7wXXEVpui2tkxri
            kbpmyA+wCQHIah62gthwVQAUq7h3ZtgXJreFtYQJdMdcpLV3+ZfSS7+I3ktVhk38CmY0KCupdw
            9hDyf4DVTgDth2VHu5qAvj2sftS3+tDLH+XtKca/YeckyiJNkvVhqc26+tSC1WJolmptWFvZGk
            SM1WTSUV4LVGNplnWVEimujlYk1oRAKR3BE4xhjKyFmeWDKp6/wkotH5YVk1Ser+4Acy+P8Fpb
            RiRbAPPty1cMP1JGtTs742Pcr/th4VX7LpnFzMa/Vnltrrqutn113doWG5kjtsKkSDEVmX/lUo
            Nfgc5IDgo0vewWU9klbyF/LnwUPByuR7rBE/FHnMGNtLuMvD7TlF05UOuE6yO80TyIPmYQ2O/R
            dkd0W2AjtbPFZn2o7kH03R9Dhorqp/rSbruGAcTSkehZXdi0YeL0WHS6MdYuYX5tQ7HWxlahFS
            3MjSLG4wUR/kiWZce3FrFrd5urBcxVLnJcgufLPHPmSUW5W/0KNZZKTwJM8DELbwV54cJz60WF
            vuIVszrm3aHq8vcfmXKMXpPEka4sW7u+g0AfbumqmmT+VFnurKxX+2t1ShUPkWuPPYu16ZRrN/
            5Xf+Wv+OvqXT0P67VfDWh1rVXhQMJOvZD8Qv29FgMdzxHjIAzvgkyvnQU299cpTPwz7JYPU34P
            Fqm9ItNoxVofOlP/Ar3ZXHKPID0C+/vB2zIIHWektwJ+B34K+X30Yy9o1L8GVg1miuUbKPzVR+
            NXUNbXWfrm+33yS6QA1bYpS9f+up2BcS3EvzmI9QeeCez8hfzSUE19a1f+Cbb3JTbakS3Qloaq
            DRPFR3+uVkwkis/KwAfblv3nSutPfyz4j9UfDuyJ1T7YFvdgY+XtQrUD/I8L3gaWTwPkZ0xpXP
            kLu+rxWn4Zfv8Av3cj1Wakv7vsIb5q6n7MRk1qdR8g/z7NRoftS8R8fqhrO3dN06aK5t/fsHsJ
            /u1Fqj/KjTMH94YWzIe6Bv8HK7O28QoteKsAAAAASUVORK5CYII=" style="width:180px">
        <p style="margin-top: 15px; margin-bottom: 15px;">
            <span style="font-size:1.3em;">'''
html += title
html += '''</p>
<table>
<tr>
    <th>Cluster</th>
    <th>Date</th>
    <th>Task</th>
    <th>Object</th>
    <th>Type</th>
    <th>Target</th>
    <th>Status</th>
    <th>Duration (Min)</th>
    <th>User</th>
</tr>'''

entityType = ['Unknown', 'VMware', 'HyperV', 'SQL', 'View', 'Puppeteer',
              'Physical', 'Pure', 'Azure', 'Netapp', 'Agent', 'GenericNas',
              'Acropolis', 'PhysicalFiles', 'Isilon', 'KVM', 'AWS', 'Exchange',
              'HyperVVSS', 'Oracle', 'GCP', 'FlashBlade', 'AWSNative', 'VCD',
              'O365', 'O365Outlook', 'HyperFlex', 'GCPNative', 'AzureNative',
              'AD', 'AWSSnapshotManager', 'GPFS', 'RDSSnapshotManager', 'Kubernetes',
              'Nimble', 'AzureSnapshotManager', 'Elastifile', 'Cassandra', 'MongoDB',
              'HBase', 'Hive', 'Hdfs', 'Couchbase', 'Unknown', 'Unknown', 'Unknown']

for clustername in clusternames:
    if mcm or vip.lower() == 'helios.cohesity.com':
        heliosCluster(clustername)

    # restores = api('get', '/restoretasks?_includeTenantInfo=true&endTimeUsecs=%s&restoreTypes=kCloneView&restoreTypes=kConvertAndDeployVMs&restoreTypes=kCloneApp&restoreTypes=kCloneVMs&restoreTypes=kDeployVMs&restoreTypes=kMountFileVolume&restoreTypes=kMountVolumes&restoreTypes=kSystem&restoreTypes=kRecoverApp&restoreTypes=kRecoverSanVolume&restoreTypes=kRecoverVMs&restoreTypes=kRestoreFiles&restoreTypes=kRecoverVolumes&restoreTypes=kDownloadFiles&restoreTypes=kRecoverEmails&restoreTypes=kRecoverDisks&startTimeUsecs=%s&targetType=kLocal' % (uEnd, uStart))
    restores = api('get', '/restoretasks?_includeTenantInfo=true&endTimeUsecs=%s&startTimeUsecs=%s&targetType=kLocal' % (uEnd, uStart))
    for restore in restores:
        taskId = restore['restoreTask']['performRestoreTaskState']['base']['taskId']
        taskName = restore['restoreTask']['performRestoreTaskState']['base']['name']
        status = restore['restoreTask']['performRestoreTaskState']['base']['publicStatus'][1:]
        startTime = usecsToDate(restore['restoreTask']['performRestoreTaskState']['base']['startTimeUsecs'])
        startTimeUsecs = restore['restoreTask']['performRestoreTaskState']['base']['startTimeUsecs']
        restoreUser = restore['restoreTask']['performRestoreTaskState']['base']['user']
        duration = '-'
        if 'endTimeUsecs' in restore['restoreTask']['performRestoreTaskState']['base']:
            endTime = usecsToDate(restore['restoreTask']['performRestoreTaskState']['base']['endTimeUsecs'])
            endTimeUsecs = restore['restoreTask']['performRestoreTaskState']['base']['endTimeUsecs']
            duration = round((endTimeUsecs - startTimeUsecs) / (60000000))

        if 'objects' in restore['restoreTask']['performRestoreTaskState']:
            for object in restore['restoreTask']['performRestoreTaskState']['objects']:
                objectType = entityType[object['entity']['type']]
                targetObject = objectName = object['entity']['displayName']
                # vmware prefix/suffix
                if 'renameRestoredObjectParam' in restore['restoreTask']['performRestoreTaskState']:
                    if 'prefix' in restore['restoreTask']['performRestoreTaskState']['renameRestoredObjectParam']:
                        targetObject = '%s%s' % (restore['restoreTask']['performRestoreTaskState']['renameRestoredObjectParam']['prefix'], targetObject)
                    if 'suffix' in restore['restoreTask']['performRestoreTaskState']['renameRestoredObjectParam']:
                        targetObject = '%s%s' % (targetObject, restore['restoreTask']['performRestoreTaskState']['renameRestoredObjectParam']['suffix'])
                # netapp, isilon, genericNas
                if 'restoreInfo' in restore['restoreTask']['performRestoreTaskState'] and restore['restoreTask']['performRestoreTaskState']['restoreInfo']['type'] in [9, 11, 14]:
                    targetObject = restore['restoreTask']['performRestoreTaskState']['fullViewName']
                if status == 'Failure':
                    html += '<tr style="color:BA3415;">'
                else:
                    html += '<tr>'
                html += '''<td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                </tr>''' % (clustername, startTime, taskName, objectName, objectType, targetObject, status, duration, restoreUser)
                csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (clustername, startTime, taskName, objectName, objectType, targetObject, status, duration, restoreUser))
        elif 'restoreAppTaskState' in restore['restoreTask']['performRestoreTaskState']:
            targetServer = sourceServer = restore['restoreTask']['performRestoreTaskState']['restoreAppTaskState']['restoreAppParams']['ownerRestoreInfo']['ownerObject']['entity']['displayName']
            for restoreAppObject in restore['restoreTask']['performRestoreTaskState']['restoreAppTaskState']['restoreAppParams']['restoreAppObjectVec']:
                objectName = restoreAppObject['appEntity']['displayName']
                objectType = entityType[restoreAppObject['appEntity']['type']]
                if 'targetHost' in restoreAppObject['restoreParams']:
                    if restoreAppObject['restoreParams']['targetHost']['displayName']:
                        targetServer = restoreAppObject['restoreParams']['targetHost']['displayName']
                targetObject = targetServer
                # sql target
                if 'sqlRestoreParams' in restoreAppObject['restoreParams']:
                    if 'instanceName' in restoreAppObject['restoreParams']['sqlRestoreParams']:
                        if restoreAppObject['restoreParams']['sqlRestoreParams']['instanceName']:
                            targetObject += '/%s' % restoreAppObject['restoreParams']['sqlRestoreParams']['instanceName']
                    if 'newDatabaseName' in restoreAppObject['restoreParams']['sqlRestoreParams']:
                        if restoreAppObject['restoreParams']['sqlRestoreParams']['newDatabaseName']:
                            targetObject += '/%s' % restoreAppObject['restoreParams']['sqlRestoreParams']['newDatabaseName']
                # oracle target
                if 'oracleRestoreParams' in restoreAppObject['restoreParams']:
                    if 'alternateLocationParams' in restoreAppObject['restoreParams']['oracleRestoreParams']:
                        if 'newDatabaseName' in restoreAppObject['restoreParams']['oracleRestoreParams']['alternateLocationParams']:
                            targetObject += '/%s' % restoreAppObject['restoreParams']['oracleRestoreParams']['alternateLocationParams']['newDatabaseName']
                if targetObject == targetServer:
                    targetObject = '%s/%s' % (targetServer, objectName)
                if status == 'Failure':
                    html += '<tr style="color:BA3415;">'
                else:
                    html += '<tr>'
                html += '''<td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s/%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                </tr>''' % (clustername, startTime, taskName, sourceServer, objectName, objectType, targetObject, status, duration, restoreUser)
                csv.write('"%s","%s","%s","%s/%s","%s","%s","%s","%s","%s"\n' % (clustername, startTime, taskName, sourceServer, objectName, objectType, targetObject, status, duration, restoreUser))
        else:
            print("***************more types****************")

html += '''</table>
</div>
</body>
</html>
'''

print('\nsaving report as %s' % htmlfileName)
print('             and %s\n' % csvfileName)

f = codecs.open(htmlfileName, 'w', 'utf-8')
f.write(html)
f.close()
csv.close()
