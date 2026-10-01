$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'aws-query.ps1')
$statePath = Join-Path $PSScriptRoot '.aws-local/nginx-website.json'
if (Test-Path -LiteralPath $statePath) { throw 'Deployment state already exists. Inspect it before launching another instance.' }
$region = 'ap-south-1'
$group = Invoke-AwsQuery CreateSecurityGroup @{'GroupName'='nginx-website-20260909';'GroupDescription'='Public HTTP for EC2 Nginx website';'VpcId'='vpc-0fc82c8c782807859'} -Region $region
$groupId = [string]$group.CreateSecurityGroupResponse.groupId
@{Region=$region;SecurityGroupId=$groupId} | ConvertTo-Json | Set-Content -LiteralPath $statePath
$null = Invoke-AwsQuery AuthorizeSecurityGroupIngress @{'GroupId'=$groupId;'IpPermissions.1.IpProtocol'='tcp';'IpPermissions.1.FromPort'='80';'IpPermissions.1.ToPort'='80';'IpPermissions.1.IpRanges.1.CidrIp'='0.0.0.0/0'} -Region $region
$userData = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'nginx-user-data.sh')))
$parameters = @{
 'ImageId'='ami-094210f044117049d';'InstanceType'='t3.micro';'MinCount'='1';'MaxCount'='1'
 'ClientToken'='nginx-website-20260909';'UserData'=$userData;'KeyName'='EC5-key-20260908060102'
 'NetworkInterface.1.DeviceIndex'='0';'NetworkInterface.1.SubnetId'='subnet-09d1d4d4fe19bc482'
 'NetworkInterface.1.AssociatePublicIpAddress'='true';'NetworkInterface.1.SecurityGroupId.1'=$groupId
 'BlockDeviceMapping.1.DeviceName'='/dev/xvda';'BlockDeviceMapping.1.Ebs.VolumeSize'='8'
 'BlockDeviceMapping.1.Ebs.VolumeType'='gp3';'BlockDeviceMapping.1.Ebs.Encrypted'='true';'BlockDeviceMapping.1.Ebs.DeleteOnTermination'='true'
 'MetadataOptions.HttpTokens'='required';'MetadataOptions.HttpEndpoint'='enabled';'CreditSpecification.CpuCredits'='standard'
 'TagSpecification.1.ResourceType'='instance';'TagSpecification.1.Tag.1.Key'='Name';'TagSpecification.1.Tag.1.Value'='nginx-website'
}
$result = Invoke-AwsQuery RunInstances $parameters -Region $region
$instanceId = [string]$result.RunInstancesResponse.instancesSet.item.instanceId
@{Region=$region;InstanceId=$instanceId;SecurityGroupId=$groupId;Name='nginx-website'} | ConvertTo-Json | Set-Content -LiteralPath $statePath
Get-Content -LiteralPath $statePath
