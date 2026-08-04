param(
    [Parameter(Mandatory = $true)][string] $BaseCubin,
    [Parameter(Mandatory = $true)][string] $Iq3Cubin,
    [Parameter(Mandatory = $true)][string] $OutputCubin
)

$ErrorActionPreference = 'Stop'

$sectionOffset = 0x3e6980
$sectionSize = 7552
$base = [IO.File]::ReadAllBytes($BaseCubin)
$iq3 = [IO.File]::ReadAllBytes($Iq3Cubin)
if ($base.Length -ne $iq3.Length -or $base.Length -lt $sectionOffset + $sectionSize) {
    throw 'Cubin layout or size mismatch'
}

[Array]::Copy($iq3, $sectionOffset, $base, $sectionOffset, $sectionSize)
[IO.File]::WriteAllBytes($OutputCubin, $base)

[pscustomobject]@{
    base = $BaseCubin
    iq3 = $Iq3Cubin
    output = $OutputCubin
    section_offset = ('0x{0:x}' -f $sectionOffset)
    section_bytes = $sectionSize
}
