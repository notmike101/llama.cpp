param(
    [Parameter(Mandatory = $true)][string] $BaseCubin,
    [Parameter(Mandatory = $true)][string] $DonorCubin,
    [Parameter(Mandatory = $true)][string] $OutputCubin
)

$ErrorActionPreference = 'Stop'

$sectionOffset = 0x887700
$sectionSize = 47104
$instructionSize = 16
$base = [IO.File]::ReadAllBytes($BaseCubin)
$donor = [IO.File]::ReadAllBytes($DonorCubin)
if ($base.Length -ne $donor.Length -or $base.Length -lt $sectionOffset + $sectionSize) {
    throw 'Cubin layout or size mismatch'
}

$patched = 0
$semantic = 0
for ($relative = 0; $relative -lt $sectionSize; $relative += $instructionSize) {
    $offset = $sectionOffset + $relative
    $baseOpcode = [BitConverter]::ToUInt64($base, $offset)
    $donorOpcode = [BitConverter]::ToUInt64($donor, $offset)
    $baseControl = [BitConverter]::ToUInt64($base, $offset + 8)
    $donorControl = [BitConverter]::ToUInt64($donor, $offset + 8)
    if ($baseOpcode -ne $donorOpcode) {
        ++$semantic
        continue
    }
    if ($baseControl -ne $donorControl) {
        [BitConverter]::GetBytes($donorControl).CopyTo($base, $offset + 8)
        ++$patched
    }
}

[IO.File]::WriteAllBytes($OutputCubin, $base)

[pscustomobject]@{
    base = $BaseCubin
    donor = $DonorCubin
    output = $OutputCubin
    schedule_instructions = $patched
    semantic_instructions_skipped = $semantic
}
