param(
    [string]$Profile = 'ticketing-dev',
    [string]$Region = 'ap-northeast-2',
    [ValidateRange(1024, 65535)][int]$LocalPort = 16686
)

$ErrorActionPreference = 'Stop'
$previousPath = $env:PATH
if (-not (Get-Command session-manager-plugin -ErrorAction SilentlyContinue)) {
    $pluginDirectory = Join-Path $PSScriptRoot 'private/session-manager/package/bin'
    if (-not (Test-Path (Join-Path $pluginDirectory 'session-manager-plugin.exe'))) {
        throw 'Install the AWS Session Manager plugin and reopen PowerShell first.'
    }
    $env:PATH = "$pluginDirectory;$env:PATH"
}
$previousProfile = $env:AWS_PROFILE
try {
    $env:AWS_PROFILE = $Profile
    $instance = terraform "-chdir=$PSScriptRoot" output -raw monitoring_ec2_instance_id
    if ($LASTEXITCODE -ne 0 -or $instance -notmatch '^i-[0-9a-f]+$') {
        throw 'Could not resolve the monitoring instance from Terraform outputs.'
    }
    Write-Host "Open http://localhost:$LocalPort after the tunnel connects. Keep this terminal open; Ctrl+C closes the tunnel."
    aws ssm start-session --profile $Profile --region $Region --target $instance `
        --document-name AWS-StartPortForwardingSession `
        --parameters "portNumber=16686,localPortNumber=$LocalPort"
    if ($LASTEXITCODE -ne 0) { throw 'SSM port forwarding failed.' }
} finally {
    $env:AWS_PROFILE = $previousProfile
    $env:PATH = $previousPath
}
