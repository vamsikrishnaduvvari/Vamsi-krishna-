param([string]$Email)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'aws-signed.ps1')
function Invoke-ServiceQuery([string]$Service,[string]$Version,[string]$Action,[hashtable]$Parameters) {
    $Parameters.Action=$Action; $Parameters.Version=$Version
    $body=($Parameters.Keys | Sort-Object | ForEach-Object { [Uri]::EscapeDataString($_)+'='+[Uri]::EscapeDataString([string]$Parameters[$_]) }) -join '&'
    [xml](Invoke-SignedAws $Service 'ap-south-1' 'POST' '/' $body 'application/x-www-form-urlencoded')
}
$instanceId='i-00503c53ba2290213'
$null=Invoke-AwsQuery MonitorInstances @{'InstanceId.1'=$instanceId}
$topic=Invoke-ServiceQuery 'sns' '2010-03-31' 'CreateTopic' @{Name='nginx-website-cpu-alerts'}
$topicArn=[string]$topic.CreateTopicResponse.CreateTopicResult.TopicArn
$null=Invoke-ServiceQuery 'monitoring' '2010-08-01' 'PutMetricAlarm' @{
 AlarmName='nginx-website-high-cpu';AlarmDescription='Average CPU exceeds 80 percent for one minute. Missing data is not breaching for scheduled stops.'
 Namespace='AWS/EC2';MetricName='CPUUtilization';Statistic='Average';Unit='Percent';Period='60';EvaluationPeriods='1';DatapointsToAlarm='1'
 Threshold='80';ComparisonOperator='GreaterThanThreshold';TreatMissingData='notBreaching';ActionsEnabled='true'
 'Dimensions.member.1.Name'='InstanceId';'Dimensions.member.1.Value'=$instanceId;'AlarmActions.member.1'=$topicArn
}
if ($Email) {
    $null=[System.Net.Mail.MailAddress]::new($Email)
    $subscriptions=Invoke-ServiceQuery 'sns' '2010-03-31' 'ListSubscriptionsByTopic' @{TopicArn=$topicArn}
    $existing=$subscriptions.ListSubscriptionsByTopicResponse.ListSubscriptionsByTopicResult.Subscriptions.member | Where-Object { $_.Endpoint -eq $Email -and $_.Protocol -eq 'email' }
    if (-not $existing) { $null=Invoke-ServiceQuery 'sns' '2010-03-31' 'Subscribe' @{TopicArn=$topicArn;Protocol='email';Endpoint=$Email} }
}
$alarm=Invoke-ServiceQuery 'monitoring' '2010-08-01' 'DescribeAlarms' @{'AlarmNames.member.1'='nginx-website-high-cpu'}
$alarm.Save((Join-Path $PSScriptRoot '.aws-local/cpu-alarm.xml'))
$alarm.DescribeAlarmsResponse.DescribeAlarmsResult.MetricAlarms.member | Select-Object AlarmName,StateValue,Threshold,Period,EvaluationPeriods,ActionsEnabled,TreatMissingData | ConvertTo-Json
$subscriptions=Invoke-ServiceQuery 'sns' '2010-03-31' 'ListSubscriptionsByTopic' @{TopicArn=$topicArn}
$subscriptions.ListSubscriptionsByTopicResponse.ListSubscriptionsByTopicResult.Subscriptions.member | Select-Object Protocol,SubscriptionArn | ConvertTo-Json
Write-Output "Topic: $topicArn"
