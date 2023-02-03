#!/usr/bin/env python

from flask import Flask, send_file

app = Flask(__name__)
app.debug = True


@app.route('/6.6.0d_u6_release-20221204_c03629f0', methods=['GET'])
def download660d():
    return send_file('cohesity-6.6.0d_u6_release-20221204_c03629f0.tar.gz', as_attachment=True)


@app.route('/', methods=['GET'])
def rootpage():
    return '''
<h2>Cohesity Upgrade Server</h2>
<br/>
<a href='6.6.0d_u6_release-20221204_c03629f0'>6.6.0d_u6_release-20221204_c03629f0</a><br/>
'''


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, threaded=True)
