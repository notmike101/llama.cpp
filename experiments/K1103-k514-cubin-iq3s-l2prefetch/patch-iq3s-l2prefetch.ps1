param(
    [Parameter(Mandatory = $true)][string] $InputCubin,
    [Parameter(Mandatory = $true)][string] $OutputCubin
)

$ErrorActionPreference = 'Stop'

$sectionOffset = 0x3e6980
$instructionOffsets = @(
    0x480, 0x4e0, 0x540, 0x550, 0x590, 0x640,
    0x650, 0x660, 0x680, 0x690, 0x6b0, 0x6c0,
    0x6d0, 0x6f0, 0x710, 0x730, 0x790, 0x7b0,
    0x810, 0x850, 0x8a0, 0x8d0, 0x8f0, 0x900
)

$bytes = [IO.File]::ReadAllBytes($InputCubin)
foreach ($instructionOffset in $instructionOffsets) {
    $offset = $sectionOffset + $instructionOffset
    $opcode = [BitConverter]::ToUInt64($bytes, $offset)
    $control = [BitConverter]::ToUInt64($bytes, $offset + 8)
    if (($opcode -band 0xffff) -ne 0x7981) {
        throw ('Unexpected opcode at kernel offset 0x{0:x}' -f $instructionOffset)
    }
    if (($control -band 0x20) -ne 0) {
        throw ('Cache hint already set at kernel offset 0x{0:x}' -f $instructionOffset)
    }
    [BitConverter]::GetBytes([UInt64] ($control -bor 0x20)).CopyTo($bytes, $offset + 8)
}

[IO.File]::WriteAllBytes($OutputCubin, $bytes)

[pscustomobject]@{
    input = $InputCubin
    output = $OutputCubin
    patched_instructions = $instructionOffsets.Count
}
