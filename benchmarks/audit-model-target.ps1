[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('qwen36_35b_a3b_mtp_q3km', 'qwen36_27b_mtp_q4km')]
    [string]$Target,
    [switch]$HashModel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$targets = Get-Content -Raw (Join-Path $PSScriptRoot 'model-targets.json') | ConvertFrom-Json
$contract = $targets.PSObject.Properties[$Target].Value
$model = Join-Path $root $contract.model_path
$engine = Join-Path $root $contract.promoted_engine
$failures = [Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $model)) { $failures.Add("missing model: $model") }
if (-not (Test-Path -LiteralPath $engine)) { $failures.Add("missing engine: $engine") }
if (Test-Path -LiteralPath $model) {
    $size = (Get-Item -LiteralPath $model).Length
    if ($contract.PSObject.Properties['model_bytes'] -and $size -ne [long]$contract.model_bytes) {
        $failures.Add("model size mismatch: $size")
    }
    if ($HashModel) {
        $hash = (Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash
        if ($hash -ne $contract.model_sha256) { $failures.Add("model hash mismatch: $hash") }
    }
}
if ((Test-Path -LiteralPath $engine) -and $contract.PSObject.Properties['promoted_engine_sha256']) {
    $hash = (Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash
    if ($hash -ne $contract.promoted_engine_sha256) { $failures.Add("engine hash mismatch: $hash") }
}
if ((Test-Path -LiteralPath $engine) -and $contract.PSObject.Properties['promoted_cuda_sha256']) {
    $cuda = Join-Path (Split-Path $engine) 'ggml-cuda.dll'
    $hash = (Get-FileHash -LiteralPath $cuda -Algorithm SHA256).Hash
    if ($hash -ne $contract.promoted_cuda_sha256) { $failures.Add("CUDA DLL hash mismatch: $hash") }
}

$campaign = Join-Path $PSScriptRoot $contract.campaign
$identities = @(Get-ChildItem -LiteralPath $campaign -Recurse -Filter IDENTITY.json -ErrorAction SilentlyContinue)
$mismatched = [Collections.Generic.List[string]]::new()
foreach ($identityFile in $identities) {
    $identity = Get-Content -Raw -LiteralPath $identityFile.FullName | ConvertFrom-Json
    if ($identity.PSObject.Properties['model_sha256'] -and $identity.model_sha256 -ne $contract.model_sha256) {
        $mismatched.Add($identityFile.FullName)
    }
}

$result = [ordered]@{
    target = $Target
    model = $model
    model_sha256 = $contract.model_sha256
    engine = $engine
    identity_files_checked = $identities.Count
    mismatched_identity_files = @($mismatched)
    failures = @($failures)
    passed = $failures.Count -eq 0 -and $mismatched.Count -eq 0
}
$result | ConvertTo-Json -Depth 8
if (-not $result.passed) { exit 1 }
