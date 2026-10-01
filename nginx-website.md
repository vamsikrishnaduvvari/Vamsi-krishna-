# EC2 Nginx website

Current status (2026-09-09): both daily EventBridge schedules are **DISABLED**, and the CPU alarm's notification actions are **DISABLED**, as requested. The instance is **stopped**. Earlier sections below describe the original setup; running the setup scripts again re-enables their respective schedules or alarm actions. The CPU alarm, SNS subscription, and detailed monitoring configuration remain present.

## CPU monitoring

CloudWatch alarm `nginx-website-high-cpu` monitors `AWS/EC2` → `CPUUtilization` for `i-00503c53ba2290213`. It alerts when the one-minute average exceeds 80% (one breaching period). EC2 detailed monitoring is enabled and may incur charges. Missing data is treated as not breaching, to accommodate scheduled stops.

Alarm notifications target SNS topic `nginx-website-cpu-alerts`. An email subscription was requested and is pending recipient confirmation. Open the AWS Notification subscription confirmation email and select **Confirm subscription** to enable delivery. No high-CPU event or end-to-end email delivery has been tested. The instance was stopped during configuration, and the alarm initially reported `INSUFFICIENT_DATA`.

`monitor-ec2.ps1` applies the alarm and optionally subscribes an email using `-Email`. `aws-signed.ps1` supplies AWS request signing. Configuration is saved in `.aws-local/cpu-alarm.xml`.

## Daily start and stop schedule

Enabled EventBridge Scheduler schedules in `ap-south-1`, timezone `Asia/Kolkata`:

- `nginx-website-daily-start`: `cron(7 12 * * ? *)` — start daily at 12:07 PM.
- `nginx-website-daily-stop`: `cron(10 12 * * ? *)` — stop daily at 12:10 PM.

Both target only `i-00503c53ba2290213`. Flexible time windows are off. Retries are disabled to avoid a delayed start after the short operating window. The IAM role `nginx-website-daily-scheduler` permits only EC2 start/stop on this instance and trusts EventBridge Scheduler from this account's default schedule group. Configuration was read back and verified as enabled; scheduled execution has not yet been observed.

Manage or disable these in AWS Console → Amazon EventBridge → Scheduler → Schedules (Mumbai region). `schedule-ec2.ps1` creates or updates the schedules; retrieved settings are saved under `.aws-local/`. Start/stop transitions and boot take time, so this is not a guarantee of three minutes of website availability. Stopping and starting can change the website's public IP.

Website: http://65.2.187.152

- Instance: `i-00503c53ba2290213` (`nginx-website`)
- Region: `ap-south-1` (Mumbai)
- OS: Amazon Linux 2023
- Instance type: `t3.micro`, standard CPU credits
- Storage: 8 GiB encrypted gp3, deleted on termination
- Security group: `sg-0740c62f911ebad59`, public TCP port 80 only
- IMDSv2 required
- Website file on server: `/usr/share/nginx/html/index.html`
- Nginx starts automatically on boot.

The initial page and setup commands are in `nginx-user-data.sh`. `launch-nginx.ps1` records deployment state in `.aws-local/nginx-website.json` and refuses another launch when that file exists. EC5 was left unchanged. The existing EC5 key pair is attached, but SSH is not open in this instance's security group.

This deployment uses HTTP. A domain and TLS certificate are needed to add HTTPS. The public IP can change after stopping and starting the instance.

Compute, EBS storage, and public IPv4 charges apply according to your AWS account's pricing and credits. Stop the instance when idle to stop compute charges; storage remains billable. Termination deletes its root disk and website, so keep source files locally.

Check status from this workspace:

```powershell
. .\aws-query.ps1
$r = Invoke-AwsQuery DescribeInstances @{'InstanceId.1'='i-00503c53ba2290213'}
$r.DescribeInstancesResponse.reservationSet.item.instancesSet.item
```

AWS documentation: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html
