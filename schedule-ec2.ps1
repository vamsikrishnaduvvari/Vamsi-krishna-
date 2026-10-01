$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'aws-query.ps1')
function Invoke-SignedAws([string]$Service, [string]$Region, [string]$Method, [string]$Path, [string]$Body, [string]$ContentType) {
    $endpoint = if ($Service -eq 'iam') { 'iam.amazonaws.com' } else { "$Service.$Region.amazonaws.com" }
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
    $day = $stamp.Substring(0,8)
    $headersMap = [ordered]@{'content-type'=$ContentType;'host'=$endpoint;'x-amz-date'=$stamp}
    if ($script:AwsCredentials['AWS_SESSION_TOKEN']) { $headersMap['x-amz-security-token']=$script:AwsCredentials['AWS_SESSION_TOKEN'] }
    $canonicalHeaders = ''
    foreach ($entry in $headersMap.GetEnumerator()) { $canonicalHeaders += $entry.Key + ':' + $entry.Value + "`n" }
    $signedHeaders = $headersMap.Keys -join ';'
    $canonicalRequest = "$Method`n$Path`n`n" + $canonicalHeaders + "`n" + $signedHeaders + "`n" + (Get-Sha256Hex $Body)
    $scope = "$day/$Region/$Service/aws4_request"
    $stringToSign = "AWS4-HMAC-SHA256`n$stamp`n$scope`n" + (Get-Sha256Hex $canonicalRequest)
    $dateKey = Get-HmacBytes ([Text.Encoding]::UTF8.GetBytes('AWS4' + $script:AwsCredentials['AWS_SECRET_ACCESS_KEY'])) $day
    $regionKey = Get-HmacBytes $dateKey $Region
    $serviceKey = Get-HmacBytes $regionKey $Service
    $signingKey = Get-HmacBytes $serviceKey 'aws4_request'
    $signature = ([BitConverter]::ToString((Get-HmacBytes $signingKey $stringToSign))).Replace('-', '').ToLowerInvariant()
    $headers = @{'X-Amz-Date'=$stamp;'Authorization'=('AWS4-HMAC-SHA256 Credential=' + $script:AwsCredentials['AWS_ACCESS_KEY_ID'] + '/' + $scope + ', SignedHeaders=' + $signedHeaders + ', Signature=' + $signature)}
    if ($script:AwsCredentials['AWS_SESSION_TOKEN']) { $headers['X-Amz-Security-Token']=$script:AwsCredentials['AWS_SESSION_TOKEN'] }
    $argsMap = @{Uri="https://$endpoint$Path";Method=$Method;Headers=$headers;ContentType=$ContentType;UseBasicParsing=$true;TimeoutSec=45}
    if ($Method -ne 'GET') { $argsMap.Body=$Body }
    (Invoke-WebRequest @argsMap).Content
}
function Invoke-Iam([string]$Action, [hashtable]$Parameters) {
    $Parameters.Action=$Action; $Parameters.Version='2010-05-08'
    $body = ($Parameters.Keys | Sort-Object | ForEach-Object { [Uri]::EscapeDataString($_) + '=' + [Uri]::EscapeDataString([string]$Parameters[$_]) }) -join '&'
    [xml](Invoke-SignedAws 'iam' 'us-east-1' 'POST' '/' $body 'application/x-www-form-urlencoded')
}
$state = Get-Content (Join-Path $PSScriptRoot '.aws-local/nginx-website.json') -Raw | ConvertFrom-Json
$instance = Invoke-AwsQuery DescribeInstances @{'InstanceId.1'=$state.InstanceId} -Region $state.Region
$account = [string]$instance.DescribeInstancesResponse.reservationSet.item.ownerId
$roleName = 'nginx-website-daily-scheduler'
$trust = @{Version='2012-10-17';Statement=@(@{Effect='Allow';Principal=@{Service='scheduler.amazonaws.com'};Action='sts:AssumeRole';Condition=@{StringEquals=@{'aws:SourceAccount'=$account};ArnEquals=@{'aws:SourceArn'="arn:aws:scheduler:$($state.Region):${account}:schedule-group/default"}}})} | ConvertTo-Json -Depth 10 -Compress
try { $role = Invoke-Iam GetRole @{RoleName=$roleName}; $roleArn=[string]$role.GetRoleResponse.GetRoleResult.Role.Arn }
catch {
    if ($_.ErrorDetails.Message -notmatch 'NoSuchEntity') { throw }
    $role = Invoke-Iam CreateRole @{RoleName=$roleName;AssumeRolePolicyDocument=$trust;Description='Start and stop nginx-website daily in India time'}
    $roleArn=[string]$role.CreateRoleResponse.CreateRoleResult.Role.Arn
}
$policy = @{Version='2012-10-17';Statement=@(@{Effect='Allow';Action=@('ec2:StartInstances','ec2:StopInstances');Resource="arn:aws:ec2:$($state.Region):${account}:instance/$($state.InstanceId)"})} | ConvertTo-Json -Depth 6 -Compress
$null = Invoke-Iam PutRolePolicy @{RoleName=$roleName;PolicyName='StartStopNginxInstanceOnly';PolicyDocument=$policy}
foreach ($operation in @('stop','start')) {
    $minute = if ($operation -eq 'start') { 7 } else { 10 }
    $name = "nginx-website-daily-$operation"
    $body = @{ClientToken=[Guid]::NewGuid().ToString();Name=$name;GroupName='default';Description="Daily $operation nginx-website at 12:$('{0:00}' -f $minute) Asia/Kolkata";ScheduleExpression="cron($minute 12 * * ? *)";ScheduleExpressionTimezone='Asia/Kolkata';FlexibleTimeWindow=@{Mode='OFF'};State='ENABLED';Target=@{Arn="arn:aws:scheduler:::aws-sdk:ec2:${operation}Instances";RoleArn=$roleArn;Input=(@{InstanceIds=@($state.InstanceId)} | ConvertTo-Json -Compress);RetryPolicy=@{MaximumEventAgeInSeconds=60;MaximumRetryAttempts=0}}} | ConvertTo-Json -Depth 10 -Compress
    $method='POST'
    try { $null=Invoke-SignedAws 'scheduler' $state.Region 'GET' "/schedules/$name" '' 'application/json'; $method='PUT' }
    catch { if ($_.Exception.Response.StatusCode.value__ -ne 404) { throw } }
    for ($attempt=0; $attempt -lt 6; $attempt++) {
        try { $null=Invoke-SignedAws 'scheduler' $state.Region $method "/schedules/$name" $body 'application/json'; break }
        catch { if ($_.ErrorDetails.Message -notmatch 'assume' -or $attempt -eq 5) { throw }; Start-Sleep -Seconds 5 }
    }
    $verified=Invoke-SignedAws 'scheduler' $state.Region 'GET' "/schedules/$name" '' 'application/json' | ConvertFrom-Json
    $verified | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $PSScriptRoot ".aws-local/$name.json")
    $verified | Select-Object Name,State,ScheduleExpression,ScheduleExpressionTimezone,Target | ConvertTo-Json -Depth 6
}
