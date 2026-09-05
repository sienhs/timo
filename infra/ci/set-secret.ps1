<#
After terraform apply, run from the repository root:
  ./infra/ci/set-secret.ps1 -Kind runner
  ./infra/ci/set-secret.ps1 -Kind webhook

runner: paste the authentication token from the project Runner creation screen.
webhook: enter a random secret of at least 32 characters, also used in GitLab's Secret token field.
The secure prompt hides input. Values are not passed on the command line or stored in Terraform.
AWS_PROFILE may select a previously authenticated CLI profile.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('runner', 'webhook')]
    [string]$Kind,
    [string]$TerraformExe = 'terraform',
    [switch]$FromClipboard,
    [switch]$Generate
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command $TerraformExe -ErrorAction SilentlyContinue)) {
    $taskBundledTerraform = Join-Path $env:TEMP 'timo-codebuild-tools/terraform.exe'
    if (Test-Path -LiteralPath $taskBundledTerraform) {
        $TerraformExe = $taskBundledTerraform
    } else {
        throw 'Terraform not found. Install Terraform or supply -TerraformExe.'
    }
}

$secretArn = & $TerraformExe "-chdir=$PSScriptRoot" output -raw "${Kind}_secret_arn"
if ($LASTEXITCODE -ne 0) { throw 'Run terraform apply for infra/ci first.' }
$region = & $TerraformExe "-chdir=$PSScriptRoot" output -raw aws_region
if ($LASTEXITCODE -ne 0) { throw 'Cannot read AWS region from Terraform outputs.' }

$secureValue = $null
$taskClipboardValue = $null
if ($Generate) {
    if ($Kind -ne 'webhook') { throw '-Generate is only supported for -Kind webhook.' }
    $taskGeneratedValue = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
    Set-Clipboard -Value $taskGeneratedValue
    $secureValue = ConvertTo-SecureString $taskGeneratedValue -AsPlainText -Force
    $taskGeneratedValue = $null
} elseif ($FromClipboard) {
    $taskClipboardValue = Get-Clipboard -Raw
    if ($null -eq $taskClipboardValue) { throw 'Clipboard is empty.' }
    $taskClipboardValue = $taskClipboardValue.Trim()
    if ([string]::IsNullOrWhiteSpace($taskClipboardValue)) { throw 'Clipboard is empty.' }
    $secureValue = ConvertTo-SecureString $taskClipboardValue -AsPlainText -Force
    $taskClipboardValue = $null
} else {
    $secureValue = Read-Host "Enter $Kind secret (input hidden)" -AsSecureString
}
$taskSecretPointer = [IntPtr]::Zero
$taskSecretFile = $null
try {
    $taskSecretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
    $taskPlainSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskSecretPointer)
    # Pasting a token from GitLab can include a trailing CR/LF; discard only
    # surrounding whitespace while still rejecting whitespace inside the token.
    $taskPlainSecret = $taskPlainSecret.Trim()
    if ([string]::IsNullOrWhiteSpace($taskPlainSecret) -or $taskPlainSecret -match '\s') {
        throw 'Secret must not be empty or contain whitespace.'
    }
    if ($Kind -eq 'webhook' -and $taskPlainSecret.Length -lt 32) {
        throw 'Use a randomly generated webhook secret of at least 32 characters.'
    }

    # Keep the temporary file private even if the inherited temp directory ACL is broad.
    $taskSecretFile = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
    [IO.File]::WriteAllText($taskSecretFile, '')
    $taskAcl = New-Object System.Security.AccessControl.FileSecurity
    $taskAcl.SetAccessRuleProtection($true, $false)
    $taskIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $taskRule = New-Object System.Security.AccessControl.FileSystemAccessRule($taskIdentity, 'FullControl', 'Allow')
    $taskAcl.AddAccessRule($taskRule)
    Set-Acl -LiteralPath $taskSecretFile -AclObject $taskAcl
    [IO.File]::WriteAllText($taskSecretFile, $taskPlainSecret, (New-Object Text.UTF8Encoding($false)))
    $taskPlainSecret = $null

    & aws secretsmanager put-secret-value --region $region --secret-id $secretArn `
        --secret-string "file://$taskSecretFile" --query ARN --output text --no-cli-pager
    if ($LASTEXITCODE -ne 0) { throw 'Secret upload failed. Check AWS CLI authentication and permissions.' }
    Write-Output "$Kind secret stored."
} finally {
    $taskPlainSecret = $null
    if ($taskSecretPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskSecretPointer)
    }
    $secureValue.Dispose()
    $taskClipboardValue = $null
    if ($taskSecretFile -and (Test-Path -LiteralPath $taskSecretFile)) {
        Remove-Item -LiteralPath $taskSecretFile -Force
    }
}
