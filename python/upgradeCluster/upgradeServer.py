#!/usr/bin/env python

from flask import Flask, send_file

app = Flask(__name__)
app.debug = True


@app.route('/6.1.0b_release-20181211_b2d1609d', methods=['GET'])
def download610b():
    return send_file('cohesity-6.1.0b_release-20181211_b2d1609d.tar.gz', as_attachment=True)


@app.route('/6.1.1d_release-20190315_3d1332e6', methods=['GET'])
def download611d():
    return send_file('cohesity-6.1.1d_release-20190315_3d1332e6.tar.gz', as_attachment=True)


@app.route('/', methods=['GET'])
def rootpage():
    return '''
<h2>Cohesity Upgrade Server</h2>
<br/>
<a href='6.1.0b_release-20181211_b2d1609d'>6.1.0b_release-20181211_b2d1609d</a><br/>
<a href='6.1.1d_release-20190315_3d1332e6'>6.1.1d_release-20190315_3d1332e6</a><br/>
'''


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, threaded=True)
