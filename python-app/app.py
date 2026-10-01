from datetime import datetime, timezone
from flask import Flask, jsonify

app = Flask(__name__)

@app.get('/')
def home():
    return '''<!doctype html><html lang="en"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1"><title>Python on EC2</title>
    <style>body{font-family:system-ui;background:#101827;color:#eef3fc;max-width:760px;margin:12vh auto;padding:24px}h1{font-size:48px}p{color:#bdcce0;line-height:1.7}a{color:#79dfbb}</style></head>
    <body><p>PYTHON / FLASK / AMAZON EC2</p><h1>Your Python app is live.</h1>
    <p>Requests pass through Nginx to Gunicorn, which runs this Flask application.
    The application starts automatically when the instance boots.</p>
    <p><a href="/api/info">View live JSON response</a> &nbsp; <a href="/health">Health check</a></p></body></html>'''

@app.get('/health')
def health():
    return jsonify(status='ok')

@app.get('/api/info')
def info():
    return jsonify(application='Python on EC2', framework='Flask', time_utc=datetime.now(timezone.utc).isoformat())
