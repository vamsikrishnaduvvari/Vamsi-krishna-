param(
  [Parameter(Mandatory=$true)][string]$Service,
  [Parameter(Mandatory=$true)][string]$HostName,
  [Parameter(Mandatory=$true)][string]$Method,
  [string]$Path = '/',
  [string]$Query = '',
  [string]$Body = '',
  [string]$Target = '',
  [string]$ContentType = 'application/x-amz-json-1.1',
  [string]$Region = ''
)

$config = @{}
Get-Content -LiteralPath (Join-Path (Get-Location) '.env') | ForEach-Object {
  if ($_ -match '^\s*(AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN|AWS_DEFAULT_REGION|AWS_REGION)\s*=\s*(.*)\s*$') {
    $value = $matches[2].Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) { $value = $value.Substring(1, $value.Length - 2) }
    $config[$matches[1]] = $value
  }
}
if (-not $config.AWS_ACCESS_KEY_ID -or -not $config.AWS_SECRET_ACCESS_KEY) { throw 'AWS credentials are missing from .env.' }
$region = if ($Region) { $Region } elseif ($config.AWS_REGION) { $config.AWS_REGION } elseif ($config.AWS_DEFAULT_REGION) { $config.AWS_DEFAULT_REGION } else { 'us-east-1' }
function Hash-Hex([string]$Value) { $sha = [Security.Cryptography.SHA256]::Create(); (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)) | ForEach-Object { $_.ToString('x2') }) -join '') }
function Get-Hmac([byte[]]$Key, [string]$Data) { $hmac = New-Object Security.Cryptography.HMACSHA256(,$Key); $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($Data)) }
$now = [DateTime]::UtcNow; $amzDate = $now.ToString('yyyyMMddTHHmmssZ'); $dateStamp = $now.ToString('yyyyMMdd')
$headerMap = [ordered]@{'content-type'=$ContentType; 'host'=$HostName; 'x-amz-date'=$amzDate}
if ($Target) { $headerMap['x-amz-target'] = $Target }
if ($config.AWS_SESSION_TOKEN) { $headerMap['x-amz-security-token'] = $config.AWS_SESSION_TOKEN }
$canonicalHeaders = (($headerMap.Keys | ForEach-Object { "${_}:$($headerMap[$_])`n" }) -join '')
$signedHeaders = ($headerMap.Keys -join ';')
$canonicalRequest = "$Method`n$Path`n$Query`n$canonicalHeaders`n$signedHeaders`n$(Hash-Hex $Body)"
$scope = "$dateStamp/$region/$Service/aws4_request"
$stringToSign = "AWS4-HMAC-SHA256`n$amzDate`n$scope`n$(Hash-Hex $canonicalRequest)"
$kDate = Get-Hmac ([Text.Encoding]::UTF8.GetBytes("AWS4$($config.AWS_SECRET_ACCESS_KEY)")) $dateStamp
$kRegion = Get-Hmac $kDate $region; $kService = Get-Hmac $kRegion $Service; $kSigning = Get-Hmac $kService 'aws4_request'
$signature = (Get-Hmac $kSigning $stringToSign | ForEach-Object { $_.ToString('x2') }) -join ''
$headers = @{'Host'=$HostName; 'Content-Type'=$ContentType; 'X-Amz-Date'=$amzDate; 'Authorization'="AWS4-HMAC-SHA256 Credential=$($config.AWS_ACCESS_KEY_ID)/$scope, SignedHeaders=$signedHeaders, Signature=$signature"}
if ($Target) { $headers['X-Amz-Target'] = $Target }; if ($config.AWS_SESSION_TOKEN) { $headers['X-Amz-Security-Token'] = $config.AWS_SESSION_TOKEN }
$uri = "https://$HostName$Path"; if ($Query) { $uri += "?$Query" }
try { (Invoke-WebRequest -Uri $uri -Method $Method -Headers $headers -Body $Body -UseBasicParsing).Content } catch { throw "AWS request failed: $($_.Exception.Message)" }
