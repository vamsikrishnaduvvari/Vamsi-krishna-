#!/bin/bash
set -euxo pipefail
dnf install -y nginx
cat > /usr/share/nginx/html/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Welcome | EC2 Website</title>
  <style>
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #101827; color: #edf2fa; font-family: system-ui, sans-serif; padding: 24px; }
    main { width: min(760px, 100%); padding: clamp(28px, 7vw, 64px); border: 1px solid #33435b; border-radius: 24px; background: #172338; }
    .label { color: #79dfbb; font-size: 13px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; }
    h1 { font-size: clamp(36px, 7vw, 64px); line-height: 1.08; letter-spacing: -.04em; margin: 24px 0; }
    p { color: #bac9df; font-size: 18px; line-height: 1.7; }
    footer { border-top: 1px solid #33435b; padding-top: 24px; margin-top: 36px; color: #bac9df; font-size: 14px; }
  </style>
</head>
<body>
  <main>
    <span class="label">Amazon Web Services / EC2</span>
    <h1>Hello from the cloud.</h1>
    <p>This website is hosted on an Amazon EC2 instance and served by Nginx. Your web server is up and running.</p>
    <footer>Amazon Linux 2023 &nbsp; / &nbsp; Nginx &nbsp; / &nbsp; Mumbai region</footer>
  </main>
</body>
</html>
HTML
nginx -t
systemctl enable --now nginx
curl --fail http://127.0.0.1/
