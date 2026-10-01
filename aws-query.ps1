$ErrorActionPreference = 'Stop'
$script:AwsCredentials = @{}
Get-Content -LiteralPath (Join-Path $PSScriptRoot '.env') | ForEach-Object {
    if ($_ -match '^\s*(AWS_[A-Z_]+)\s*=(.*)$') {
        $script:AwsCredentials[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
    }
}
function Get-Sha256Hex([string]$Value) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-', '').ToLowerInvariant() }
    finally { $hasher.Dispose() }
}
function Get-HmacBytes([byte[]]$KeyBytes, [string]$Value) {
    $hmac = [Security.Cryptography.HMACSHA256]::new()
    $hmac.Key = $KeyBytes
    try { return ,$hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)) }
    finally { $hmac.Dispose() }
}
function Invoke-AwsQuery {
    param([string]$Action, [hashtable]$Parameters = @{}, [string]$Region = 'ap-south-1')
    $endpoint = "ec2.$Region.amazonaws.com"
    $query = @{ Action = $Action; Version = '2016-11-15' }
    foreach ($entry in $Parameters.GetEnumerator()) { $query[$entry.Key] = [string]$entry.Value }
    $payload = (($query.Keys | Sort-Object | ForEach-Object { [Uri]::EscapeDataString($_) + '=' + [Uri]::EscapeDataString($query[$_]) }) -join '&')
    $nowUtc = [DateTime]::UtcNow
    $stamp = $nowUtc.ToString('yyyyMMddTHHmmssZ')
    $day = $nowUtc.ToString('yyyyMMdd')
    $headersMap = [ordered]@{'content-type'='application/x-www-form-urlencoded'; 'host'=$endpoint; 'x-amz-date'=$stamp}
    if ($script:AwsCredentials['AWS_SESSION_TOKEN']) { $headersMap['x-amz-security-token'] = $script:AwsCredentials['AWS_SESSION_TOKEN'] }
    $canonicalHeaders = ''
    foreach ($entry in $headersMap.GetEnumerator()) { $canonicalHeaders += $entry.Key + ':' + $entry.Value + "`n" }
    $signedHeaders = $headersMap.Keys -join ';'
    $canonicalRequest = "POST`n/`n`n" + $canonicalHeaders + "`n" + $signedHeaders + "`n" + (Get-Sha256Hex $payload)
    $scope = "$day/$Region/ec2/aws4_request"
    $stringToSign = "AWS4-HMAC-SHA256`n$stamp`n$scope`n" + (Get-Sha256Hex $canonicalRequest)
    $dateKey = Get-HmacBytes ([Text.Encoding]::UTF8.GetBytes('AWS4' + $script:AwsCredentials['AWS_SECRET_ACCESS_KEY'])) $day
    $regionKey = Get-HmacBytes $dateKey $Region
    $serviceKey = Get-HmacBytes $regionKey 'ec2'
    $signingKey = Get-HmacBytes $serviceKey 'aws4_request'
    $signature = ([BitConverter]::ToString((Get-HmacBytes $signingKey $stringToSign))).Replace('-', '').ToLowerInvariant()
    $requestHeaders = @{'X-Amz-Date'=$stamp; 'Authorization'=('AWS4-HMAC-SHA256 Credential=' + $script:AwsCredentials['AWS_ACCESS_KEY_ID'] + '/' + $scope + ', SignedHeaders=' + $signedHeaders + ', Signature=' + $signature)}
    if ($script:AwsCredentials['AWS_SESSION_TOKEN']) { $requestHeaders['X-Amz-Security-Token'] = $script:AwsCredentials['AWS_SESSION_TOKEN'] }
    try {
        $response = Invoke-WebRequest -Uri "https://$endpoint/" -Method Post -Headers $requestHeaders -ContentType 'application/x-www-form-urlencoded' -Body $payload -UseBasicParsing -TimeoutSec 45
        return [xml]$response.Content
    } catch {
        $details = $_.ErrorDetails.Message
        if ($details -match '<Code>([^<]+)</Code>') {
            $errorCode = $matches[1]
            $errorMessage = ''
            if ($details -match '<Message>([^<]+)</Message>') { $errorMessage = $matches[1] }
            throw "AWS ${Action}: $errorCode - $errorMessage"
        }
        throw "AWS $Action request failed: $($_.Exception.Message)"
    }
}
