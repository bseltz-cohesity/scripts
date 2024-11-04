#!/usr/bin/env python
"""Helios v2 Protection Runs Report"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime, timedelta
import codecs
import os
import numbers

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-s', '--startdate', type=str, default='')
parser.add_argument('-e', '--enddate', type=str, default='')
parser.add_argument('-t', '--thismonth', action='store_true')
parser.add_argument('-l', '--lastmonth', action='store_true')
parser.add_argument('-y', '--days', type=int, default=7)
parser.add_argument('-x', '--dayrange', type=int, default=180)
parser.add_argument('-m', '--maxrecords', type=int, default=20000)
parser.add_argument('-hr', '--hours', type=int, default=0)
parser.add_argument('-n', '--units', type=str, choices=['MiB', 'GiB', 'TiB'], default='GiB')
parser.add_argument('-r', '--reportname', type=str, default='Protection Runs')
parser.add_argument('-c', '--clustername', action='append', type=str)
parser.add_argument('-z', '--timezone', type=str, default='America/New_York')
parser.add_argument('-sr', '--showrecord', action='store_true')
parser.add_argument('-f', '--filter', action='append', type=str)
parser.add_argument('-fl', '--filterlist', type=str, default=None)
parser.add_argument('-fp', '--filterproperty', type=str, default=None)
parser.add_argument('-o', '--outputpath', type=str, default='.')
parser.add_argument('-of', '--outputfile', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
startdate = args.startdate
enddate = args.enddate
thismonth = args.thismonth
lastmonth = args.lastmonth
days = args.days
hours = args.hours
units = args.units
reportname = args.reportname
dayrange = args.dayrange
clusternames = args.clustername
timezone = args.timezone
showrecord = args.showrecord
filters = args.filter
filterlist = args.filterlist
filterproperty = args.filterproperty
outputpath = args.outputpath
outputfile = args.outputfile
maxrecords = args.maxrecords


# gather server list
def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


filterTextList = gatherList(filename=filterlist, name='filter text list', required=False)

multiplier = 1024 * 1024 * 1024  # GiB
if units.lower() == 'mib':
    multiplier = 1024 * 1024
if units.lower() == 'tib':
    multiplier = 1024 * 1024 * 1024 * 1024

# authenticate
apiauth(vip=vip, username=username, domain='local', helios=True)

allClusters = heliosClusters()
for selectedCluster in allClusters:
    selectedCluster['id'] = '%s:%s' % (selectedCluster['clusterId'], selectedCluster['clusterIncarnationId'])
regions = api('get', 'dms/regions', mcmv2=True)
for region in regions['regions']:
    allClusters.append(region)

selectedClusters = allClusters

# select clusters to include
if clusternames is not None and len(clusternames) > 0:
    selectedClusters = [s for s in allClusters if s['name'].lower() in [n.lower() for n in clusternames] or str(s['id']).lower() in [n.lower() for n in clusternames]]
    unknownClusters = [c for c in clusternames if c.lower() not in [n['name'].lower() for n in allClusters] and c.lower() not in [str(n['id']).lower() for n in allClusters]]
    if unknownClusters is not None and len(unknownClusters) > 0:
        print('Clusters not found:\n %s' % ', '.join(unknownClusters))
        exit()

# date ranges
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
elif hours > 0:
    uStart = timeAgo(hours, 'hours')
    uEnd = dateToUsecs(now)
else:
    uStart = timeAgo(days, 'days')
    uEnd = dateToUsecs(now)

start = usecsToDate(uStart, '%Y-%m-%d')
end = usecsToDate(uEnd, '%Y-%m-%d')

# build 7 day time ranges
dayRangeUsecs = dayrange * 86400000000
ranges = []
gotAllRanges = False
thisUend = uEnd
thisUstart = uStart
while gotAllRanges is False:
    if (thisUend - uStart) > dayRangeUsecs:
        thisUstart = thisUend - dayRangeUsecs
        ranges.append({'start': thisUstart, 'end': thisUend})
        thisUend = thisUstart - 1
    else:
        ranges.append({'start': uStart, 'end': thisUend})
        gotAllRanges = True

# get list of available reports
reports = api('get', 'reports', reportingv2=True)
report = [r for r in reports['reports'] if r['title'].lower() == reportname.lower()]
if report is None or len(report) == 0:
    print('Invalid report name: %s' % reportname)
    print('\nAvailable report names are:\n')
    print('%s' % '\n'.join(sorted([t['title'] for t in reports['reports']])))
    exit()
reportNumber = report[0]['componentIds'][0]
title = report[0]['title']

# TSV output

if outputfile is not None:
    tsvFileName = os.path.join(outputpath, "%s.tsv" % outputfile)
    csvFileName = os.path.join(outputpath, "%s.csv" % outputfile)
    htmlFileName = os.path.join(outputpath, "%s.html" % outputfile)
else:
    tsvFileName = os.path.join(outputpath, "%s_%s_%s.tsv" % (title.replace('/', '-').replace('\\', '-'), start, end))
    csvFileName = os.path.join(outputpath, "%s_%s_%s.csv" % (title.replace('/', '-').replace('\\', '-'), start, end))
    htmlFileName = os.path.join(outputpath, "%s_%s_%s.html" % (title.replace('/', '-').replace('\\', '-'), start, end))

csv = codecs.open(csvFileName, 'w', 'utf-8')
tsv = codecs.open(tsvFileName, 'w', 'utf-8')
htmlFile = codecs.open(htmlFileName, 'w', 'utf-8')

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
            border: 1px solid #F8F8F8;
            background-color: #F8F8F8;
        }

        td {
            min-width: 18ch;
            max-width: 250px;
            text-align: left;
            padding: 10px;
            word-wrap:break-word;
            white-space:normal;
        }

        td.nowrap {
            width: 25ch;
            max-width: 250px;
            text-align: left;
            padding: 10px;
            padding-right: 15px;
            word-wrap:break-word;
            white-space:nowrap;
        }

        th {
            width: 25ch;
            max-width: 250px;
            text-align: left;
            padding: 6px;
            white-space: nowrap;
        }
    </style>
</head>
<body>

    <div style="margin:15px;">
            <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAALQAAAAaCAYAAAA
            e23asAAAACXBIWXMAABcRAAAXEQHKJvM/AAABmWlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAA
            AAPD94cGFja2V0IGJlZ2luPSfvu78nIGlkPSdXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQnP
            z4KPHg6eG1wbWV0YSB4bWxuczp4PSdhZG9iZTpuczptZXRhLycgeDp4bXB0az0nSW1hZ2U6
            OkV4aWZUb29sIDExLjcwJz4KPHJkZjpSREYgeG1sbnM6cmRmPSdodHRwOi8vd3d3LnczLm9
            yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjJz4KCiA8cmRmOkRlc2NyaXB0aW9uIHJkZj
            phYm91dD0nJwogIHhtbG5zOnBob3Rvc2hvcD0naHR0cDovL25zLmFkb2JlLmNvbS9waG90b
            3Nob3AvMS4wLyc+CiAgPHBob3Rvc2hvcDpDb2xvck1vZGU+MzwvcGhvdG9zaG9wOkNvbG9y
            TW9kZT4KIDwvcmRmOkRlc2NyaXB0aW9uPgo8L3JkZjpSREY+CjwveDp4bXBtZXRhPgo8P3h
            wYWNrZXQgZW5kPSdyJz8+enmf4AAAAIB6VFh0UmF3IHByb2ZpbGUgdHlwZSBpcHRjAAB4nG
            WNMQqAMAxF95zCI7RJ/GlnJzcHb6AtCILi/QfbDnXwBz7h8eDTvKzTcD9XPs5EQwsCSVDWq
            LvTcj0S/ObYx/KOysbwSNDOEjsIMgJGE0RTi1TQVpAhdy3/tc8yqV5bq630An5xJATDlSTX
            AAAMJ0lEQVR42uWce5RVVR3HP/fOmWEYHJlQTC1AxJBViqiIj9QyEs1Kl5qSj3ysMovV09I
            SNTHNpJWZlWbmo8zUfIGImiQ+Mh0fmYDvIMWREOQ1As6MM2fu7Y/vb8/d58y9d865MyODfd
            c6i7nn7LN/+/Hbv/chQwxBEPg/twE+CRwKTARGAFsAGaAVWAY0ArOBh4ANAGEYUg4xGlsC+
            wCTgd2BDwN1QA5YCywGHgMeBF62+2VpBEGwPXC89QPwX+DmMAxbSIggCEYAXwQG260m4JYw
            DNvseQAcBuyYtM8SaAVmh2G4Mv5g2vwp8b3YFdgZGAZkE/TdAdx25eR5S2JzG2RzG2W32mx
            uTfa8ATjR6PQFQmBWGIYvBUEwGjgWGGTPOoF7gWd74htv/ADV1s8Y79HqoEhDgAZrfAqwGw
            XG8LEFMM6uo4G/A5cDDwVB0FlqcB6NwYghTgP2NppxjAb2BL4AvAHcDVwLLAqCoBxT7wVcb
            JMGHbyHgf+k2IR9gZ8CVfZ7KTq0r9vvocAFwPgUfRZDCKxEQqELHjOPQMx1JDDW1r0qYd+d
            NuclsftbA+cCO9nvnK1vk/0eC1xkc+wL5IF3gZfQgTyfgqAAOAg4LgiCVUmZGgnZXwMf8O4
            t7DrlHqPtAfwZuAJtal2CzrcEPgfcAvwAqItJ4TiN0cBvgRuAQyjOzJFX7Z1vAXOAbwCDi9
            EwVBOVYAHJmcB/p1wfWaDG/u3NFVg/XTBmztjazEKHcy/EYGnm8RbwXJH7VUbXIRP7Xcl6l
            UPGm+OjwO2x5wcB3wSqyuypBqbnI4EZRJl5BXB21msEcDBwM5KcxXpuB9YBa5CqjGMrdPrO
            BWpLDG48cCNwMsUPSxuwHtiIpFcco4CfI+k4pASNfG93oAT6o9+s368nmY8Arkcaqtg4klx
            PAq9WMKYcyUyaSvAOkv4vxtZgGvCpci/aXtcAZyHB6xAi6+B+nxv2QVJzTKyfTuBfyM55Cl
            huE94GSfCjkVniUAOcAaw2Ip3eYHYwGvvFaLQgk+U+m+jb6EBtb20Pp6AeQfbXd4BmYGY5E
            +c9xhPAsynfabH19bEbcCmwnXdvHfA35LOspufDlbexvFvBPBYDFxKVgD4agOOAeo/WA3Q3
            bRxCe+7wb+DHwDXIhAIJwxnA80EQvFlmP49AwtDHPOAqIGe+DcORvRhn5pVIGt6A1FccDyA
            p8l3gaxQk7iDgs8DvgQ1GoxY4j+7M/KJNbi46vXHcYYP9nk2k1u5X272n0UYPBNwFXNLLPg
            bZvHxncyGSSg8jLdnfWNPDPHZAWrzeu3cdMjnLIgxDJ9xmAQcgyZyxx/siXpoeBEHoM7W9M
            wb4EYVDALL9zweawzDsMiuOt86JNfw6cI8/GB9GZBlwNmL4CxBT3gb8BpkNDgcDU2M0FgKn
            4km1EjQWI4m8HJhOwUMeBpwJPBkEwfoBIqV7i10Qszi4fWhM08mVk+f15xiLmSOZpC8bU7c
            DP0MBgYleH6chbT3XtfcE4nRbH4d2YCbwTFdbpNZOIuoEtKCTcI8bQKmBGcF24FdIoi8F/k
            HU/q1FjDvEu7cO+CHGzOVo2ITakLYYC5zgNTkA+DRwZ+/2qG/Qm0Nl9vPHkfp1uIEoM++E7
            Mdq716IzJBX0QEIp82fUjFTpwy7VjR329cmZGbcSCEw0IAk7sIgCN7w+jwGmTk+ZgF/BPKu
            XRbFfz8aa3gv8Jekg7Q2rcAfkFoMY++Oo7sGuBOzq3qiEYaha9OCbMsV3uNa4CiKO7GbI8Z
            5f7dg5pQx58eQCXYT8CfvugmFNB9EJuBkIJg2f0o8lj0QcT/yq3LevT2R5q2xwzMOOIdoqM
            /Z4Rt9/smi0FCt19AxZmvaE+f/7UlvkMPpS50W4FY1TS3RFtki+NgLOamlkAfCIAhIemHOb
            Erk09DwaDlkiNqHLcAaT9Luh6JEVdbWXVm02TugmPXtKNTXV4mRfoHtfQj8EoXz/HU4Bfi8
            zes8FL/21+UnRCMlgKTahNi9JSiaUekAi2E8URurCViUlplNTXUiSfQlCrbcdiict7zEq7U
            o1jk2Bbk9UrR1GAlMStE+hxIf6+x3nqhjPBjYyjMfFqDEzqge+m0Avg9sC3x72vwp6/rZpq
            4YtqdvITPjVgqCqR6Ff3dHGtjHTda2u8+FQmM+FgNr+9DBCoAPxe69TmETK1mAJeiUOmlWR
            zTEFUcDUmtp4shZUjg6hi8jCZkUeeRIX+bd80Nfdcg/eMRMh38iW3ISUROrHqXFD0RMjI39
            BLTWM6hM47yXeNTW4UJvbhNsXr5/txBpn7ZiPJqle3JjdR9PPiCqRkE1Gr0JP61HTqJDFeX
            TtBnkRNWkuCqxyQehrGnSayhKQwNddnIjisO7cZ+MwlmgA/A0yuJe7l0XIeY9HNnS7uBmgd
            OBiQPZljbGzKHwbNyc9Jl5PRIAr5USuJEsVT/B2Xk+cpV0lIDO+wELkGPtMAJt9BTKH7IQM
            ftpKEHlMBwVIg3o9TEGbUbapKlIkzxKxMwt10+AYsW+97g1OhV9JaVDovFoUAaqmsql9JZE
            HdkcxZMyDu0oVpm42g74INGYZxIsRXH5pMjRPbPYglTvvhTsyfGoJOFeVCD1JtH9WYNqNtp
            R6PRi5Ig7p3B/pA2aU85nU+AZFJ++lEK+AaS5LgU6ylZaorjlcO/eR2whVvXRADtQ+aaPkW
            iBU9PwMka+qdRGNJQXx1rgq5ROzRbDVBQCSyPZrkeLnhR5oqaTw6NItc6kYK4NQ/b5iYhxf
            c26EWV6L6NwSBah0l+QDzOcAc7Q5h/lUeXhGUSzpXOA5T35dlmkpnzsCEzoqeopJZ4nugGj
            gHEV0sig8JWfrVpFcTXlox0xT9Kro4KxtSNNkfRqIWZ+mR2dQ2UDZyCBE0cNkl7u2godwCH
            2fiuS4n77wWwGMIbtpHthWiJtnkX2lq+uh6BUeHUahisVW7UBPkVUOtSjUEw2LQ1URnpw7N
            ECSofsImNJelWKNDRK0TKm7EBMfRSqk1hGaTMwb2vgpH1AtM6ig8qKlDYVivldmST7EqC8+
            VMoTutwJEorzumhkF6dFL4gOBSZF8+a6nDvvoAq0T7jvTYVZSOfSEEjQHUNvioKUVHQ5rRh
            PeLKyfPwQnWnIzNrAjrQ9UQ3fBnKIHbYOyOJ2v8rUPTqfY8AxYOvQk6EU0tDkWG+BnjMSdE
            ShUMgSX8qsh/Xo9z8NchmzSPVeh06NM6Z2w5VdJ0KvJaQxinIFvY3cxFRr/59A4+pQ+AVu3
            pCFfAVxNQOjVQY99/c4LjlbpR58etMd0aFHzOQkb6xhHkwDDHZWciB2cL+3hWFi9Zbu/uQY
            X+s9+4njMZ5qKCpswSN4SgcdSaKcDi0Ar8AVgyQSrtcpb5HfPwVxo3rbJ2mUfAxmlFZZ3+E
            SgccAvMsWxHj7oSqvRzGAFejNPMsVIi+2hZna5SxmoqcNH8nm9FnXBuhy3t9BxWT7EK0GOo
            AVG46B1X3LUYf2wYobDUJHYK9iQbZneN0x6ZeRA8TUeViUmSQ3fsA0oY+qpFpVVPm/TyFz5
            vGom8vD6OgBfOoLqdxoKa++xoBdDHcUmSfXkG0Mm4wCupPQRmsDbZQ9RT/FnAdqowqJhVeQ
            N+OXU30Y4LhKG18EjoMrYh564lKZIdOVFZ5ASVSoJsIx9iVBh32zl3uhknn/ZH2qqN88ivj
            rVX8O8C5yKyrJGKzWSKuH59Dcc7pqPY0zkxDKZ9ifhnVUd8B5OIVeKaOXWHRJejg+PZwNdG
            YeDGsQR8PXAa8XYKZB3RWLIYqogkEh8koS1gJ3kUO9znAyv8X6QweQ3sM14S+rp6NnLADUd
            as1EeTORQym40Y7RXXXxwejUZkRpyMahDGUV61gpIjDyEN8gjlbcIc3Zk6bYo/z3tzMDJFx
            jYESei02IDCd9eiEtJS2dM4vQzpbOzevp+k/ziNRP1HJLTHcO3AXxED7YoyTpOQTddgE9gA
            vIbCcfNQtKHT9VMKHo2VKJJyMzJnDkEfh26LzJwcciiXAo8j9fk4lr7uwcxYBPyOwhcyrxu
            9NHjOxuYiP0uIhr42INt/t5T9xvEOSjz5yNlck0YmWtHXKo1oP7rs8RLSeS2KOrkPj9tI93
            HvKnRoRnv0F/RyHXw0I9vffewQov9sqEf8D1JlEi06AzkDAAAAAElFTkSuQmCC" style="width:180px">
        <p style="margin-top: 15px; margin-bottom: 15px;">
            <span style="font-size:1.3em;">'''

html += title

html += '''</span>
<span style="font-size:1em; text-align: right; padding-right: 2px; float: right;">'''

html += '%s to %s' % (start, end)

html += '''</span>
</p>
<table>
<tr style="background-color: #F1F1F1;">'''

gotHeadings = False
headings = []

for cluster in sorted(selectedClusters, key=lambda c: c['name'].lower()):
    print(cluster['name'])
    for range in ranges:
        csvLines = []
        tsvLines = []
        reportParams = {
            "filters": [
                {
                    "attribute": "date",
                    "filterType": "TimeRange",
                    "timeRangeFilterParams": {
                        "lowerBound": range['start'],
                        "upperBound": range['end']
                    }
                },
                {
                    "attribute": "systemId",
                    "filterType": "Systems",
                    "systemsFilterParams": {
                        "systemIds": [cluster['id']],
                        "systemNames": [cluster['name']]
                    }
                }
            ],
            "sort": None,
            "timezone": timezone,
            "limit": {
                "size": maxrecords,
            }
        }
        preview = api('post', 'components/%s/preview' % reportNumber, reportParams, reportingv2=True)
        if len(preview['component']['data']) == maxrecords:
            print('Hit limit of records. Try reducing --dayrange (e.g. --dayrange 1)')
            exit()
        print('    -')
        attributes = preview['component']['config']['xlsxParams']['attributeConfig']
        # headings
        if gotHeadings is False:
            for attribute in attributes:
                if 'customLabel' in attribute:
                    if 'bytes' in attribute['customLabel'].lower():
                        headings.append((attribute['customLabel'].replace('bytes', units).replace('Bytes', units)))
                    else:
                        headings.append(attribute['customLabel'])
                else:
                    if 'bytes' in attribute['attributeName'].lower():
                        headings.append((attribute['attributeName'].replace('bytes', units).replace('Bytes', units)))
                    else:
                        headings.append(attribute['attributeName'])
            gotHeadings = True
            tsvHeadings = '\t'.join(headings)
            tsv.write('%s\n' % tsvHeadings)
            csvHeadings = ','.join(headings)
            csv.write('%s\n' % csvHeadings)
            htmlHeadings = '\n'.join(['<th>%s</th>' % h for h in headings])
            html += htmlHeadings
            html += '</tr>'
        if 'format' in attributes[0] and attributes[0]['format'].lower() == 'timestamp':
            previewData = sorted(preview['component']['data'], key=lambda d: d[attributes[0]['attributeName']], reverse=True)
        else:
            previewData = sorted(preview['component']['data'], key=lambda d: d[attributes[0]['attributeName']])
        if filters is not None and len(filters) > 0:
            for filter in filters:
                if '==' in filter:
                    (fattrib, fvalue) = filter.split('==')
                elif '!=' in filter:
                    (fattrib, fvalue) = filter.split('!=')
                elif '>=' in filter:
                    (fattrib, fvalue) = filter.split('>=')
                elif '<=' in filter:
                    (fattrib, fvalue) = filter.split('<=')
                elif '<' in filter:
                    (fattrib, fvalue) = filter.split('<')
                elif '>' in filter:
                    (fattrib, fvalue) = filter.split('>')
                else:
                    print('\nInvalid filter format, should be one of ==, !=, <=, >=, <, >\n')
                    exit()
                fattrib = fattrib.strip()
                fvalue = fvalue.strip()
                if len(previewData) > 0 and fattrib not in previewData[0]:
                    print('\nInvalid filter attribute: %s\nUse --showrecord to see attribute names\n' % fattrib)
                    exit()
                else:
                    if fvalue.isnumeric():
                        fvalue = float(fvalue)
                    if '==' in filter:
                        previewData = [p for p in previewData if p[fattrib] == fvalue]
                    elif '!=' in filter:
                        previewData = [p for p in previewData if p[fattrib] != fvalue]
                    elif '>=' in filter:
                        previewData = [p for p in previewData if p[fattrib] >= fvalue]
                    elif '<=' in filter:
                        previewData = [p for p in previewData if p[fattrib] <= fvalue]
                    elif '<' in filter:
                        previewData = [p for p in previewData if p[fattrib] < fvalue]
                    elif '>' in filter:
                        previewData = [p for p in previewData if p[fattrib] > fvalue]
        if filterlist and filterproperty:
            if previewData and filterproperty not in previewData[0]:
                print('\nInvalid filter attribute: %s\nUse --showrecord to see attribute names\n' % filterproperty)
                exit()
            else:
                filteredPreviewData = []
                for p in previewData:
                    if filterproperty in p and p[filterproperty] is not None:
                        if type(p[filterproperty]) is list:
                            includeItem = False
                            for i in p[filterproperty]:
                                if i.lower() in [f.lower() for f in filterTextList]:
                                    includeItem = True
                            if includeItem is True:
                                filteredPreviewData.append(p)
                        else:
                            if p[filterproperty].lower() in [f.lower() for f in filterTextList]:
                                filteredPreviewData.append(p)
                previewData = filteredPreviewData
                # previewData = [p for p in previewData if filterproperty in p and p[filterproperty] is not None and str(p[filterproperty]).lower() in [f.lower() for f in filterTextList]]
        for rec in previewData:
            if showrecord:
                display(rec)
                exit()
            csvColumns = []

            html += '<tr>'
            for attribute in attributes:
                data = rec[attribute['attributeName']]
                if 'format' in attribute and attribute['format'].lower() == 'timestamp':
                    data = usecsToDate(data)
                elif 'usecs' in attribute['attributeName'].lower():
                    data = int(data / 1000000)
                if 'percent' in attribute['attributeName'].lower():
                    data = round(data, 1)
                elif 'customLabel' in attribute:
                    if 'bytes' in attribute['customLabel'].lower() or \
                       'consumed' in attribute['customLabel'].lower() or \
                       'capacity' in attribute['customLabel'].lower() or \
                       'read' in attribute['customLabel'].lower() or \
                       'written' in attribute['customLabel'].lower() or \
                       'size' in attribute['customLabel'].lower() or \
                       'daily' in attribute['customLabel'].lower() or \
                       'data' in attribute['customLabel'].lower():
                        data = round(data / multiplier, 1)
                else:
                    if 'bytes' in attribute['attributeName'].lower() or \
                       'consumed' in attribute['attributeName'].lower() or \
                       'capacity' in attribute['attributeName'].lower() or \
                       'read' in attribute['attributeName'].lower() or \
                       'written' in attribute['attributeName'].lower() or \
                       'size' in attribute['attributeName'].lower() or \
                       'daily' in attribute['attributeName'].lower() or \
                       'data' in attribute['attributeName'].lower():
                        data = round(data / multiplier, 1)
                if isinstance(data, numbers.Number):
                    data = round(data, 1)
                csvColumns.append(data)
                html += '<td>%s</td>' % data
            html += '</tr>'
            csvLine = ','.join([str(i) for i in csvColumns])
            csvLines.append('%s\n' % csvLine)
            tsvLine = '\t'.join([str(i) for i in csvColumns])
            tsvLines.append('%s\n' % tsvLine)

        csv.write(''.join(sorted(csvLines)))
        tsv.write(''.join(sorted(tsvLines)))

html += '''</table>
</div>
</body>
</html>'''

htmlFile.write(html)
htmlFile.close()
csv.close()
tsv.close()

print('\nOutput saved to %s\nAlso saved to %s\nand %s\n' % (htmlFileName, csvFileName, tsvFileName))
