$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'aws-query.ps1')
$state = Get-Content -LiteralPath (Join-Path $PSScriptRoot '.aws-local\EC5.json') -Raw | ConvertFrom-Json
$result = Invoke-AwsQuery DescribeInstances @{'InstanceId.1'=$state.InstanceId} -Region $state.Region
$instance = $result.DescribeInstancesResponse.reservationSet.item.instancesSet.item
if ($instance.instanceState.name -ne 'running' -or -not $instance.ipAddress) {
    throw 'EC5 must be running with a public IP before connecting.'
}
$knownHosts = Join-Path $PSScriptRoot '.ssh\known_hosts'
$console = Invoke-AwsQuery GetConsoleOutput @{'InstanceId'=$state.InstanceId;'Latest'='true'} -Region $state.Region
if ($console.GetConsoleOutputResponse.output) {
    $consoleText = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$console.GetConsoleOutputResponse.output))
    if ($consoleText -match '(?m)^\s*(ssh-ed25519\s+[A-Za-z0-9+/=]+)') {
        $knownHost = [string]$instance.ipAddress + ' ' + $matches[1]
        if (-not (Test-Path -LiteralPath $knownHosts) -or -not ((Get-Content -LiteralPath $knownHosts) -contains $knownHost)) {
            Add-Content -LiteralPath $knownHosts -Value $knownHost -Encoding ascii
        }
    }
}
Push-Location -LiteralPath $PSScriptRoot
try {
    & ssh -i '.ssh/EC5.pem' -o UserKnownHostsFile=.ssh/known_hosts -o StrictHostKeyChecking=yes -o HostKeyAlgorithms=ssh-ed25519 "ubuntu@$($instance.ipAddress)"
    $sshExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $sshExitCode
