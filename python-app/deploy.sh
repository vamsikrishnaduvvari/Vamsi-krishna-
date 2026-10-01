#!/bin/bash
set -euo pipefail
dnf install -y python3 python3-pip nginx
id ec2web >/dev/null 2>&1 || useradd --system --shell /sbin/nologin ec2web
install -d -m 755 /opt/ec2-python-app
install -m 644 /tmp/app.py /opt/ec2-python-app/app.py
python3 -m venv /opt/ec2-python-app/venv
/opt/ec2-python-app/venv/bin/pip install 'Flask>=3.1,<3.2' 'gunicorn>=23,<24'
/opt/ec2-python-app/venv/bin/pip freeze > /opt/ec2-python-app/requirements.lock
cat > /etc/systemd/system/ec2-python-app.service <<'EOF'
[Unit]
Description=Python Flask application via Gunicorn
After=network.target
[Service]
User=ec2web
Group=ec2web
WorkingDirectory=/opt/ec2-python-app
ExecStart=/opt/ec2-python-app/venv/bin/gunicorn --workers 2 --bind 127.0.0.1:8000 --access-logfile - --error-logfile - app:app
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
Environment=PYTHONDONTWRITEBYTECODE=1
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable ec2-python-app
systemctl restart ec2-python-app
for attempt in {1..15}; do curl -fsS http://127.0.0.1:8000/health && break || sleep 1; done
curl -fsS http://127.0.0.1:8000/health
test -f /etc/nginx/nginx.conf.before-python || cp -p /etc/nginx/nginx.conf /etc/nginx/nginx.conf.before-python
cat > /etc/nginx/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    server_tokens off;
    server {
        listen 80 default_server;
        server_name _;
        location / {
            proxy_pass http://127.0.0.1:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF
nginx -t
systemctl reload nginx
for attempt in {1..15}; do curl -fsS http://127.0.0.1/health && break || sleep 1; done
curl -fsS http://127.0.0.1/health
systemctl is-enabled ec2-python-app nginx
