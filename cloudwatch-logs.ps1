param(
    [string]$InstanceId = 'i-00503c53ba2290213',
    [string]$Region = 'ap-south-1',
    [string]$LogGroup = '/ec2/nginx-website/application'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'aws-signed.ps1')

function Get-OrCreateRole {
    try { return (Invoke-Iam 'GetRole' @{ RoleName = 'nginx-website-cloudwatch-agent' }).GetRoleResponse.GetRoleResult.Role }
    catch {
        $trust = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
        return (Invoke-Iam 'CreateRole' @{ RoleName = 'nginx-website-cloudwatch-agent'; AssumeRolePolicyDocument = $trust; Description = 'Allows the CloudWatch agent on nginx-website to publish application logs.' }).CreateRoleResponse.CreateRoleResult.Role
    }
}

function Get-OrCreateInstanceProfile {
    try { return (Invoke-Iam 'GetInstanceProfile' @{ InstanceProfileName = 'nginx-website-cloudwatch-agent' }).GetInstanceProfileResponse.GetInstanceProfileResult.InstanceProfile }
    catch { return (Invoke-Iam 'CreateInstanceProfile' @{ InstanceProfileName = 'nginx-website-cloudwatch-agent' }).CreateInstanceProfileResponse.CreateInstanceProfileResult.InstanceProfile }
}

$role = Get-OrCreateRole
$null = Invoke-Iam 'AttachRolePolicy' @{ RoleName = $role.RoleName; PolicyArn = 'arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy' }
$null = Invoke-Iam 'AttachRolePolicy' @{ RoleName = $role.RoleName; PolicyArn = 'arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore' }
$profile = Get-OrCreateInstanceProfile
try { $null = Invoke-Iam 'AddRoleToInstanceProfile' @{ InstanceProfileName = $profile.InstanceProfileName; RoleName = $role.RoleName } } catch { }

# The instance does not currently have an instance profile. Associate this one before its next boot.
$null = Invoke-AwsQuery 'AssociateIamInstanceProfile' @{ 'IamInstanceProfile.Name' = $profile.InstanceProfileName; InstanceId = $InstanceId } $Region

# Preserve the existing user-data, then append a one-time CloudWatch Agent setup.
$attribute = Invoke-AwsQuery 'DescribeInstanceAttribute' @{ InstanceId = $InstanceId; Attribute = 'userData' } $Region
$encoded = [string]$attribute.DescribeInstanceAttributeResponse.userData.value
$existing = if ($encoded) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded)) } else { '#!/bin/bash' }
$setup = @"

# CloudWatch Logs collection (managed by cloudwatch-logs.ps1)
if [ ! -f /var/lib/amazon-cloudwatch-agent/.nginx-website-logs-configured ]; then
  yum install -y amazon-cloudwatch-agent
  install -d -o ec2web -g ec2web -m 0755 /var/log/ec2-python-app
  install -d -m 0755 /etc/systemd/system/ec2-python-app.service.d
  cat > /etc/systemd/system/ec2-python-app.service.d/cloudwatch-logs.conf <<'EOF'
[Service]
StandardOutput=append:/var/log/ec2-python-app/app.log
StandardError=append:/var/log/ec2-python-app/app.log
EOF
  cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {"file_path":"/var/log/ec2-python-app/app.log","log_group_name":"$LogGroup","log_stream_name":"{instance_id}/application","timezone":"UTC"},
          {"file_path":"/var/log/nginx/access.log","log_group_name":"$LogGroup","log_stream_name":"{instance_id}/nginx-access","timezone":"UTC"},
          {"file_path":"/var/log/nginx/error.log","log_group_name":"$LogGroup","log_stream_name":"{instance_id}/nginx-error","timezone":"UTC"}
        ]
      }
    }
  }
}
EOF
  systemctl daemon-reload
  systemctl restart ec2-python-app nginx
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  touch /var/lib/amazon-cloudwatch-agent/.nginx-website-logs-configured
fi
"@
$newUserData = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($existing + $setup))
$null = Invoke-AwsQuery 'ModifyInstanceAttribute' @{ InstanceId = $InstanceId; 'UserData.Value' = $newUserData } $Region
$null = Invoke-AwsQuery 'StartInstances' @{ 'InstanceId.1' = $InstanceId } $Region

[pscustomobject]@{ InstanceId = $InstanceId; InstanceProfile = $profile.InstanceProfileName; LogGroup = $LogGroup; Status = 'starting' } | ConvertTo-Json
