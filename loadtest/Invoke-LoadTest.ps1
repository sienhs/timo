[CmdletBinding()]
param(
    [string]$ProjectName = 'ticketing',
    [string]$Environment = 'dev',
    [string[]]$UserLevels = @('10000'),
    [string]$Duration = '35m',
    [int]$QueueActiveLimit = 0,
    [string[]]$QueueActiveLimits = @('400'),
    [int]$AppInstanceCount = 6,
    [int]$DbPoolSize = 20,
    [int]$QueueIngressSpreadSeconds = 10,
    [switch]$IgnoreFlowSlo = $true,
    [switch]$KeepInfrastructure
)

$ErrorActionPreference = 'Stop'
[int[]]$UserLevels = @(
    $UserLevels |
        ForEach-Object { $_ -split ',' } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ } |
        ForEach-Object {
            $parsed = 0
            if (-not [int]::TryParse($_, [ref]$parsed)) {
                throw "UserLevels must be comma-separated integers (for example: 600,800,1000). Invalid value: $_"
            }
            $parsed
        }
)
[string[]]$queueActiveLimitInputs = if ($QueueActiveLimit -gt 0) {
    @([string]$QueueActiveLimit)
} else {
    @($QueueActiveLimits | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
[int[]]$QueueActiveLimits = @(
    $queueActiveLimitInputs | ForEach-Object {
        $parsed = 0
        if (-not [int]::TryParse($_, [ref]$parsed)) {
            throw "QueueActiveLimits must be comma-separated integers (for example: 200,400,800). Invalid value: $_"
        }
        $parsed
    }
)
if ($QueueActiveLimits.Count -eq 0) { throw 'Specify at least one QueueActiveLimit.' }
if (@($QueueActiveLimits | Where-Object { $_ -lt 1 -or $_ -gt 2000 }).Count -gt 0) { throw 'QueueActiveLimits must be between 1 and 2000.' }
if ($QueueActiveLimits.Count -gt 1) {
    if ($KeepInfrastructure) { throw '-KeepInfrastructure cannot be used with multiple QueueActiveLimits.' }
    foreach ($limit in $QueueActiveLimits) {
        Write-Host "`n=== Queue active-limit $limit ==="
        & $PSCommandPath -ProjectName $ProjectName -Environment $Environment -UserLevels ($UserLevels -join ',') -Duration $Duration -QueueActiveLimit $limit -AppInstanceCount $AppInstanceCount -DbPoolSize $DbPoolSize -QueueIngressSpreadSeconds $QueueIngressSpreadSeconds -IgnoreFlowSlo:$IgnoreFlowSlo
        if ($LASTEXITCODE -ne 0) { throw "Load test stopped at QueueActiveLimit $limit." }
    }
    exit 0
}
$QueueActiveLimit = $QueueActiveLimits[0]
$scriptRoot = Split-Path -Parent $PSScriptRoot
$loadtestInfra = Join-Path $scriptRoot 'infra/loadtest'
$tfvars = Join-Path $loadtestInfra 'terraform.tfvars'
$planFile = Join-Path $loadtestInfra 'loadtest.tfplan'
$runScript = Join-Path $PSScriptRoot 'run.mjs'
$created = $false

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required. Install it and ensure it is on PATH."
    }
}
function AwsJson([string[]]$Arguments) {
    $text = & aws @Arguments '--output' 'json'
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI failed: aws $($Arguments -join ' ')" }
    return $text | ConvertFrom-Json
}
function ExactlyOne($Values, [string]$Description) {
    $found = @($Values)
    if ($found.Count -ne 1) { throw "${Description}: expected one result, found $($found.Count). Check -ProjectName/-Environment and AWS tags." }
    return $found[0]
}
function To-HclString([string]$Value) { '"' + $Value.Replace('\\', '\\').Replace('"', '\"') + '"' }
function Get-StandardVcpuUsage {
    $reservations = (AwsJson @('ec2', 'describe-instances', '--filters', 'Name=instance-state-name,Values=pending,running')).Reservations
    $instances = @($reservations | ForEach-Object { $_.Instances } | Where-Object { $_.InstanceType -match '^(a|c|d|h|i|m|r|t|z)\d' })
    $instanceTypes = @($instances | ForEach-Object { $_.InstanceType } | Sort-Object -Unique)
    if ($instanceTypes.Count -eq 0) { return 0 }
    $typeInfo = AwsJson (@('ec2', 'describe-instance-types', '--instance-types') + $instanceTypes)
    $vcpusByType = @{}
    $typeInfo.InstanceTypes | ForEach-Object { $vcpusByType[$_.InstanceType] = [int]$_.VCpuInfo.DefaultVCpus }
    return [int](($instances | ForEach-Object { $vcpusByType[$_.InstanceType] } | Measure-Object -Sum).Sum)
}

Require-Command terraform
Require-Command aws
Require-Command node
Require-Command k6
if ($Duration -notmatch '^\d+[ms]$') { throw 'Duration must be like 5m or 30s.' }
if (@($UserLevels | Where-Object { $_ -lt 1 -or $_ -gt 10000 }).Count -gt 0) { throw 'UserLevels must be between 1 and 10000.' }
if ($AppInstanceCount -lt 1 -or $AppInstanceCount -gt 6) { throw 'AppInstanceCount must be between 1 and 6 for the current 32-vCPU quota.' }
if ($DbPoolSize -lt 1 -or $DbPoolSize -gt 20) { throw 'DbPoolSize must be between 1 and 20.' }
if ($QueueIngressSpreadSeconds -lt 0 -or $QueueIngressSpreadSeconds -gt 600) { throw 'QueueIngressSpreadSeconds must be between 0 and 600.' }

$identity = AwsJson @('sts', 'get-caller-identity')
$ip = (Invoke-RestMethod -Uri 'https://checkip.amazonaws.com' -TimeoutSec 10).Trim()
if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { throw 'Could not determine your public IPv4 address.' }
$prefix = "$ProjectName-$Environment"
$appInstanceType = 'c7i.xlarge'
$appTypeInfo = AwsJson @('ec2', 'describe-instance-types', '--instance-types', $appInstanceType)
$requestedVcpus = $AppInstanceCount * [int]$appTypeInfo.InstanceTypes[0].VCpuInfo.DefaultVCpus
$quotaResult = AwsJson @('service-quotas', 'get-service-quota', '--service-code', 'ec2', '--quota-code', 'L-1216C47A')
$quota = [int]$quotaResult.Quota.Value
$usedVcpus = Get-StandardVcpuUsage
if ($usedVcpus + $requestedVcpus -gt $quota) {
    throw "Insufficient On-Demand Standard vCPU quota: in use $usedVcpus + requested $requestedVcpus > quota $quota. Stop other standard instances or reduce -AppInstanceCount."
}
Write-Host "On-Demand Standard vCPU preflight: in use $usedVcpus + requested $requestedVcpus <= quota $quota."

$vpc = ExactlyOne (AwsJson @('ec2', 'describe-vpcs', '--filters', "Name=tag:Name,Values=$prefix-vpc")).Vpcs "VPC $prefix-vpc"
$subnets = AwsJson @('ec2', 'describe-subnets', '--filters', "Name=vpc-id,Values=$($vpc.VpcId)")
$publicSubnets = @($subnets.Subnets | Where-Object { $_.Tags | Where-Object { $_.Key -eq 'Tier' -and $_.Value -eq 'public' } } | Sort-Object AvailabilityZone)
if ($publicSubnets.Count -lt 2) { throw 'Expected public subnets in at least two AZs for the load-test ALB.' }
$dbSubnets = @($subnets.Subnets | Where-Object { $_.Tags | Where-Object { $_.Key -eq 'Tier' -and $_.Value -eq 'private-db' } } | Sort-Object AvailabilityZone)
if ($dbSubnets.Count -lt 2) { throw 'Expected at least two private-db subnets.' }

$sourceDb = ExactlyOne (AwsJson @('rds', 'describe-db-instances', '--db-instance-identifier', "$prefix-mysql")).DBInstances "RDS $prefix-mysql"
$repository = "$prefix-backend"
$images = AwsJson @('ecr', 'describe-images', '--repository-name', $repository, '--filter', 'tagStatus=TAGGED')
$image = ExactlyOne @($images.imageDetails | Sort-Object imagePushedAt -Descending | Select-Object -First 1) "Latest ECR image in $repository"
# ECR returns only the digest; repository URL is resolved from the current account and region.
$repositoryInfo = AwsJson @('ecr', 'describe-repositories', '--repository-names', $repository)
$imageReference = "$($repositoryInfo.repositories[0].repositoryUri)@$($image.imageDigest)"

$bytes = New-Object byte[] 20
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $rng.GetBytes($bytes)
} finally {
    $rng.Dispose()
}
$dbPassword = ([BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
$redisAuthToken = $dbPassword
$tfvarsContent = @(
    "# Generated by loadtest/Invoke-LoadTest.ps1 for AWS account $($identity.Account) on $(Get-Date -Format o).",
    "vpc_id = $(To-HclString $vpc.VpcId)",
    "load_generator_cidr = $(To-HclString "$ip/32")",
    "public_subnet_ids = [$(($publicSubnets | ForEach-Object { To-HclString $_.SubnetId }) -join ', ')]",
    "db_subnet_ids = [$(($dbSubnets[0..1] | ForEach-Object { To-HclString $_.SubnetId }) -join ', ')]",
    "image = $(To-HclString $imageReference)",
    "db_engine_version = $(To-HclString $sourceDb.EngineVersion)",
    "db_instance_class = $(To-HclString 'db.t4g.medium')",
    "app_instance_type = $(To-HclString $appInstanceType)",
    "app_instance_count = $AppInstanceCount",
    "redis_auth_token = $(To-HclString $redisAuthToken)",
    "waiting_queue_active_limit = $QueueActiveLimit"
) -join [Environment]::NewLine
Set-Content -LiteralPath $tfvars -Value $tfvarsContent -NoNewline
$env:TF_VAR_db_password = $dbPassword

Write-Host "Load test target: $prefix / $AppInstanceCount x $appInstanceType behind ALB / db.t4g.medium / MySQL $($sourceDb.EngineVersion) / Hikari $DbPoolSize per app"
Write-Host "k6 generator: local $ip; test app and disposable RDS will be created."
Write-Host "Image: $imageReference"

try {
    & terraform "-chdir=$loadtestInfra" init
    if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
    & terraform "-chdir=$loadtestInfra" plan "-var-file=$tfvars" "-out=$planFile"
    if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
    $created = $true # apply can leave resources behind even if it fails partway.
    & terraform "-chdir=$loadtestInfra" apply $planFile
    if ($LASTEXITCODE -ne 0) { throw 'Terraform apply failed.' }
    $created = $true

    $env:TF_VAR_redis_auth_token = $redisAuthToken
    $env:IGNORE_FLOW_SLO = if ($IgnoreFlowSlo) { 'true' } else { 'false' }
    $env:LOADTEST_DB_POOL_SIZE = [string]$DbPoolSize
    $env:QUEUE_INGRESS_SPREAD_SECONDS = [string]$QueueIngressSpreadSeconds
    & node $runScript prepare
    if ($LASTEXITCODE -ne 0) { throw 'Test environment preparation failed.' }
    & node $runScript run 1 30s
    if ($LASTEXITCODE -ne 0) { throw 'Smoke test failed.' }
    & node $runScript run 50 3m
    if ($LASTEXITCODE -ne 0) { throw 'Warm-up failed.' }

    foreach ($users in $UserLevels) {
        & node $runScript run $users $Duration
        if ($LASTEXITCODE -eq 2) {
            throw "Capacity validation failed at $users users. Review results before increasing load."
        }
        if ($LASTEXITCODE -ne 0) { throw "Load test execution failed at $users users." }
    }
} finally {
    Remove-Item -LiteralPath $planFile -Force -ErrorAction SilentlyContinue
    if ($created -and -not $KeepInfrastructure) {
        Write-Host 'Destroying disposable test app and RDS...'
        & terraform "-chdir=$loadtestInfra" destroy '-auto-approve' "-var-file=$tfvars"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Destroy failed. Run terraform -chdir=infra/loadtest destroy -var-file=terraform.tfvars after fixing AWS access.' }
    }
    Remove-Item Env:TF_VAR_db_password -ErrorAction SilentlyContinue
    Remove-Item Env:TF_VAR_redis_auth_token -ErrorAction SilentlyContinue
    Remove-Item Env:IGNORE_FLOW_SLO -ErrorAction SilentlyContinue
    if ($created -and -not $KeepInfrastructure -and $LASTEXITCODE -ne 0) {
        throw 'Infrastructure cleanup failed; inspect Terraform state and remove remaining test resources.'
    }
}
