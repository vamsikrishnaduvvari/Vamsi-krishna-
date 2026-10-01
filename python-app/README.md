# Python application on EC2

Deployed to `nginx-website` (`i-00503c53ba2290213`) in Mumbai.

Current URL: http://65.2.124.71

- `/`: welcome page
- `/health`: JSON health response
- `/api/info`: application information and live UTC time

All three public endpoints returned HTTP 200 after deployment. Flask runs through Gunicorn on loopback port 8000, with Nginx on public port 80. The `ec2-python-app` systemd service runs as the unprivileged `ec2web` user, restarts on failure, and is enabled at boot. Installed dependency versions are in `requirements.lock`.

Application location: `/opt/ec2-python-app/app.py`. Service logs: `sudo journalctl -u ec2-python-app`. Restart after changes: `sudo systemctl restart ec2-python-app`.

The previous Nginx configuration is backed up at `/etc/nginx/nginx.conf.before-python`, and the previous static HTML remains in `/usr/share/nginx/html/index.html`. The deployment replaced the public welcome page with the Python app. Temporary SSH access used during deployment was removed.

The instance was started for deployment. Its daily 12:07 PM start / 12:10 PM stop schedule (Asia/Kolkata) remains enabled; it will stop at the next scheduled stop. The public IP can change after stop/start. HTTP is configured; HTTPS is not configured.

For redeployment, allow SSH from your IP, upload `app.py` and `deploy.sh` to `/tmp` as `ec2-user`, then run `sudo bash /tmp/deploy.sh`. Remove temporary SSH access afterwards. The deployment script resolves compatible dependencies; use `requirements.lock` with pip `-r` when reproducing the installed versions.
