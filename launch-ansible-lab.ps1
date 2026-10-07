$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'aws-query.ps1')

$region = 'ap-south-1'
$vpcId = 'vpc-0fc82c8c782807859'
$subnetId = 'subnet-09d1d4d4fe19bc482'
$amiId = 'ami-094210f044117049d'
$keyName = 'ansible-lab-key'
$privateKeyPath = Join-Path $PSScriptRoot '.ssh/ansible-lab.pem'
$publicKeyPath = "$privateKeyPath.pub"
$statePath = Join-Path $PSScriptRoot '.aws-local/ansible-lab.json'

if (Test-Path -LiteralPath $statePath) {
    throw "Ansible lab state exists at $statePath. Stop or terminate that lab before launching another one."
}
if (-not (Test-Path -LiteralPath $privateKeyPath)) {
    ssh-keygen -t ed25519 -N '""' -f $privateKeyPath | Out-Null
}
if (-not (Test-Path -LiteralPath $publicKeyPath)) {
    throw "The public key was not created at $publicKeyPath."
}

try {
    $existingKey = Invoke-AwsQuery DescribeKeyPairs @{ 'KeyName.1' = $keyName } -Region $region
    if ($existingKey.OuterXml -notmatch "<keyName>$keyName</keyName>") { throw 'Key pair was not found.' }
} catch {
    $publicKey = Get-Content -Raw -LiteralPath $publicKeyPath
    $publicKeyMaterial = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($publicKey.Trim()))
    $null = Invoke-AwsQuery ImportKeyPair @{ 'KeyName' = $keyName; 'PublicKeyMaterial' = $publicKeyMaterial } -Region $region
}

$group = Invoke-AwsQuery CreateSecurityGroup @{
    'GroupName' = ('ansible-lab-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    'GroupDescription' = 'Private SSH between Ansible lab nodes'
    'VpcId' = $vpcId
} -Region $region
$groupId = [string]$group.CreateSecurityGroupResponse.groupId
$null = Invoke-AwsQuery AuthorizeSecurityGroupIngress @{
    'GroupId' = $groupId
    'IpPermissions.1.IpProtocol' = 'tcp'
    'IpPermissions.1.FromPort' = '22'
    'IpPermissions.1.ToPort' = '22'
    'IpPermissions.1.Groups.1.GroupId' = $groupId
} -Region $region
$null = Invoke-AwsQuery AuthorizeSecurityGroupIngress @{
    'GroupId' = $groupId
    'IpPermissions.1.IpProtocol' = 'tcp'
    'IpPermissions.1.FromPort' = '80'
    'IpPermissions.1.ToPort' = '80'
    'IpPermissions.1.Groups.1.GroupId' = $groupId
} -Region $region

$targetUserData = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("#!/bin/bash`nset -euxo pipefail`ndnf install -y python3`n"))
$target = Invoke-AwsQuery RunInstances @{
    'ImageId' = $amiId; 'InstanceType' = 't3.micro'; 'MinCount' = '1'; 'MaxCount' = '1'; 'KeyName' = $keyName
    'ClientToken' = ('ansible-target-' + [guid]::NewGuid().ToString('N')); 'UserData' = $targetUserData
    'NetworkInterface.1.DeviceIndex' = '0'; 'NetworkInterface.1.SubnetId' = $subnetId; 'NetworkInterface.1.AssociatePublicIpAddress' = 'true'; 'NetworkInterface.1.SecurityGroupId.1' = $groupId
    'BlockDeviceMapping.1.DeviceName' = '/dev/xvda'; 'BlockDeviceMapping.1.Ebs.VolumeSize' = '8'; 'BlockDeviceMapping.1.Ebs.VolumeType' = 'gp3'; 'BlockDeviceMapping.1.Ebs.Encrypted' = 'true'; 'BlockDeviceMapping.1.Ebs.DeleteOnTermination' = 'true'
    'MetadataOptions.HttpTokens' = 'required'; 'MetadataOptions.HttpEndpoint' = 'enabled'; 'TagSpecification.1.ResourceType' = 'instance'; 'TagSpecification.1.Tag.1.Key' = 'Name'; 'TagSpecification.1.Tag.1.Value' = 'ansible-managed-node'
} -Region $region
$targetId = [string]$target.RunInstancesResponse.instancesSet.item.instanceId
$targetXml = $target.OuterXml
if ($targetXml -notmatch '<privateIpAddress>([^<]+)</privateIpAddress>') { throw 'Target instance did not return a private IP address.' }
$targetIp = $matches[1]

$privateKey = Get-Content -Raw -LiteralPath $privateKeyPath
$playbook = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'ansible-lab/site.yml')
$encodedKey = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($privateKey))
$encodedPlaybook = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($playbook))
$controllerLines = @(
    '#!/bin/bash', 'set -euxo pipefail', 'dnf install -y python3 python3-pip', 'python3 -m pip install --no-cache-dir ansible',
    'install -d -m 700 /home/ec2-user/.ssh',
    "echo '$encodedKey' | base64 -d > /home/ec2-user/.ssh/ansible-lab.pem", 'chmod 600 /home/ec2-user/.ssh/ansible-lab.pem',
    "cat > /home/ec2-user/inventory.ini <<'EOF'", '[managed]', "$targetIp ansible_user=ec2-user ansible_ssh_private_key_file=/home/ec2-user/.ssh/ansible-lab.pem ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'", 'EOF',
    "echo '$encodedPlaybook' | base64 -d > /home/ec2-user/site.yml", 'chown -R ec2-user:ec2-user /home/ec2-user',
    'until runuser -l ec2-user -c "ansible managed -i /home/ec2-user/inventory.ini -m ping"; do sleep 5; done',
    'runuser -l ec2-user -c "ansible-playbook -i /home/ec2-user/inventory.ini /home/ec2-user/site.yml" | tee /var/log/ansible-lab.log',
    "curl --fail http://$targetIp/ | tee -a /var/log/ansible-lab.log"
)
$controllerUserData = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($controllerLines -join "`n")))
$controller = Invoke-AwsQuery RunInstances @{
    'ImageId' = $amiId; 'InstanceType' = 't3.micro'; 'MinCount' = '1'; 'MaxCount' = '1'; 'KeyName' = $keyName
    'ClientToken' = ('ansible-controller-' + [guid]::NewGuid().ToString('N')); 'UserData' = $controllerUserData
    'NetworkInterface.1.DeviceIndex' = '0'; 'NetworkInterface.1.SubnetId' = $subnetId; 'NetworkInterface.1.AssociatePublicIpAddress' = 'true'; 'NetworkInterface.1.SecurityGroupId.1' = $groupId
    'BlockDeviceMapping.1.DeviceName' = '/dev/xvda'; 'BlockDeviceMapping.1.Ebs.VolumeSize' = '8'; 'BlockDeviceMapping.1.Ebs.VolumeType' = 'gp3'; 'BlockDeviceMapping.1.Ebs.Encrypted' = 'true'; 'BlockDeviceMapping.1.Ebs.DeleteOnTermination' = 'true'
    'MetadataOptions.HttpTokens' = 'required'; 'MetadataOptions.HttpEndpoint' = 'enabled'; 'TagSpecification.1.ResourceType' = 'instance'; 'TagSpecification.1.Tag.1.Key' = 'Name'; 'TagSpecification.1.Tag.1.Value' = 'ansible-controller'
} -Region $region
$controllerId = [string]$controller.RunInstancesResponse.instancesSet.item.instanceId
@{ Region = $region; SecurityGroupId = $groupId; ControllerInstanceId = $controllerId; ManagedInstanceId = $targetId; ManagedPrivateIp = $targetIp } | ConvertTo-Json | Set-Content -LiteralPath $statePath
Get-Content -LiteralPath $statePath
