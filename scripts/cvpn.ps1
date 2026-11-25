[CmdletBinding()]
param(
    [ValidateSet('init', 'check', 'pull', 'up', 'down', 'status', 'logs')]
    [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$deployDirectory = Join-Path $projectRoot 'deploy'
$envFile = Join-Path $deployDirectory '.env'
$composeFile = Join-Path $deployDirectory 'compose.yaml'

if ($Action -eq 'init') {
    if (Test-Path -LiteralPath $envFile) {
        Write-Output 'deploy/.env already exists; left unchanged.'
    } else {
        Copy-Item -LiteralPath (Join-Path $deployDirectory '.env.example') -Destination $envFile
        Write-Output 'Created deploy/.env. See README.cvpn.md before starting.'
    }
    return
}

if (-not (Test-Path -LiteralPath $envFile)) {
    throw 'Missing deploy/.env. Run: ./scripts/cvpn.ps1 init'
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker with Compose v2 is required. See README.cvpn.md.'
}

$composeArguments = @('compose', '--env-file', $envFile, '-f', $composeFile)
switch ($Action) {
    'check'  { $composeArguments += @('config', '--quiet') }
    'pull'   { $composeArguments += @('pull') }
    'up'     { $composeArguments += @('up', '-d') }
    'down'   { $composeArguments += @('down') }
    'status' { $composeArguments += @('ps') }
    'logs'   { $composeArguments += @('logs', '--tail=100', '-f') }
}

& docker @composeArguments
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose failed with exit code $LASTEXITCODE."
}
