$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'aws-query.ps1')

$region = 'ap-south-1'
$repoRaw = 'https://raw.githubusercontent.com/vamsikrishnaduvvari/Vamsi-krishna-/main/community-bloom'
$userDataLines = @(
    '#!/bin/bash',
    'set -euxo pipefail',
    'dnf install -y nginx',
    'rm -rf /usr/share/nginx/html/*',
    'mkdir -p /usr/share/nginx/html/images',
    "curl --fail --location --retry 5 '$repoRaw/index.html' -o /usr/share/nginx/html/index.html",
    "curl --fail --location --retry 5 '$repoRaw/styles.css' -o /usr/share/nginx/html/styles.css",
    "curl --fail --location --retry 5 '$repoRaw/images/community-garden-hero.png' -o /usr/share/nginx/html/images/community-garden-hero.png",
    'nginx -t',
    'systemctl enable --now nginx',
    'curl --fail http://127.0.0.1/'
)
$userData = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($userDataLines -join "`n")))

$result = Invoke-AwsQuery RunInstances @{
    'ImageId' = 'ami-094210f044117049d'; 'InstanceType' = 't3.micro'; 'MinCount' = '1'; 'MaxCount' = '1'
    'ClientToken' = ('community-bloom-' + [guid]::NewGuid().ToString('N')); 'UserData' = $userData
    'NetworkInterface.1.DeviceIndex' = '0'; 'NetworkInterface.1.SubnetId' = 'subnet-09d1d4d4fe19bc482'; 'NetworkInterface.1.AssociatePublicIpAddress' = 'true'; 'NetworkInterface.1.SecurityGroupId.1' = 'sg-064df4725d220b9da'
    'BlockDeviceMapping.1.DeviceName' = '/dev/xvda'; 'BlockDeviceMapping.1.Ebs.VolumeSize' = '8'; 'BlockDeviceMapping.1.Ebs.VolumeType' = 'gp3'; 'BlockDeviceMapping.1.Ebs.Encrypted' = 'true'; 'BlockDeviceMapping.1.Ebs.DeleteOnTermination' = 'true'
    'MetadataOptions.HttpTokens' = 'required'; 'MetadataOptions.HttpEndpoint' = 'enabled'; 'TagSpecification.1.ResourceType' = 'instance'; 'TagSpecification.1.Tag.1.Key' = 'Name'; 'TagSpecification.1.Tag.1.Value' = 'community-bloom'
} -Region $region
$instanceId = [string]$result.RunInstancesResponse.instancesSet.item.instanceId
@{ Region = $region; InstanceId = $instanceId; Name = 'community-bloom' } | ConvertTo-Json
