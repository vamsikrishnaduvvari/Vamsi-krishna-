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
