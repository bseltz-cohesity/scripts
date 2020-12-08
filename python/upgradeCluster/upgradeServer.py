#!/usr/bin/env python

from flask import Flask, send_file

app = Flask(__name__)
app.debug = True


@app.route('/6.5.1c_release-20201119_ec194046', methods=['GET'])
def download651c():
    return send_file('cohesity-6.5.1c_release-20201119_ec194046.tar.gz', as_attachment=True)


@app.route('/', methods=['GET'])
def rootpage():
    return '''
<h2>Cohesity Upgrade Server</h2>
<br/>
<a href='6.5.1c_release-20201119_ec194046'>6.5.1c_release-20201119_ec194046</a><br/>
'''


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, threaded=True)
