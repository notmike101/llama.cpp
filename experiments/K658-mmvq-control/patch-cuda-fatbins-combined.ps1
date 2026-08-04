param(
    [Parameter(Mandatory = $true)][string] $InputDll,
    [Parameter(Mandatory = $true)][string] $OutputDll,
    [string] $Q4Fatbin = '',
    [string] $Q5Fatbin = '',
    [string] $Q6Fatbin = '',
    [string] $MmvqFatbin = '',
    [string] $CpyFatbin = '',
    [string] $GdnFatbin = ''
)

$ErrorActionPreference = 'Stop'

function Align-Up([UInt64] $Value, [UInt64] $Alignment) {
    return [UInt64] ([Math]::Floor(
        ($Value + $Alignment - 1) / [double] $Alignment) * $Alignment)
}

function Put-U16([byte[]] $Bytes, [int] $Offset, [UInt16] $Value) {
    [BitConverter]::GetBytes($Value).CopyTo($Bytes, $Offset)
}

function Put-U32([byte[]] $Bytes, [int] $Offset, [UInt32] $Value) {
    [BitConverter]::GetBytes($Value).CopyTo($Bytes, $Offset)
}

function Put-U64([byte[]] $Bytes, [int] $Offset, [UInt64] $Value) {
    [BitConverter]::GetBytes($Value).CopyTo($Bytes, $Offset)
}

$source = [IO.File]::ReadAllBytes($InputDll)
$replacements = @()
if ($Q4Fatbin) {
    $replacements += [pscustomobject]@{ Wrapper = 116; Path = $Q4Fatbin }
}
if ($Q5Fatbin) {
    $replacements += [pscustomobject]@{ Wrapper = 119; Path = $Q5Fatbin }
}
if ($Q6Fatbin) {
    $replacements += [pscustomobject]@{ Wrapper = 120; Path = $Q6Fatbin }
}
if ($MmvqFatbin) {
    $replacements += [pscustomobject]@{ Wrapper = 39; Path = $MmvqFatbin }
}
if ($CpyFatbin) {
    $replacements += [pscustomobject]@{ Wrapper = 17; Path = $CpyFatbin }
}
if ($GdnFatbin) {
    $replacements += [pscustomobject]@{ Wrapper = 1; Path = $GdnFatbin }
}
foreach ($replacement in $replacements) {
    $replacement | Add-Member -NotePropertyName Image -NotePropertyValue (
        [IO.File]::ReadAllBytes($replacement.Path))
    if ([BitConverter]::ToUInt32($replacement.Image, 0) -ne 3126193488) {
        throw "Replacement is not a fatbin: $($replacement.Path)"
    }
}

$peOffset = [BitConverter]::ToInt32($source, 0x3c)
if ([BitConverter]::ToUInt32($source, $peOffset) -ne 0x00004550) {
    throw 'Input is not a PE image'
}

$coff = $peOffset + 4
$sectionCount = [BitConverter]::ToUInt16($source, $coff + 2)
$optionalSize = [BitConverter]::ToUInt16($source, $coff + 16)
$optional = $coff + 20
if ([BitConverter]::ToUInt16($source, $optional) -ne 0x20b) {
    throw 'Input is not PE32+'
}

$imageBase = [BitConverter]::ToUInt64($source, $optional + 24)
$sectionAlignment = [BitConverter]::ToUInt32($source, $optional + 32)
$fileAlignment = [BitConverter]::ToUInt32($source, $optional + 36)
$sizeOfHeaders = [BitConverter]::ToUInt32($source, $optional + 60)
$sectionTable = $optional + $optionalSize
$newHeader = $sectionTable + 40*$sectionCount
if ($newHeader + 40 -gt $sizeOfHeaders) {
    throw 'PE header has no room for another section'
}

$sections = @()
for ($i = 0; $i -lt $sectionCount; ++$i) {
    $offset = $sectionTable + 40*$i
    $nameBytes = $source[$offset..($offset + 7)]
    $zero = [Array]::IndexOf($nameBytes, [byte] 0)
    if ($zero -ge 0) {
        $nameBytes = $nameBytes[0..([Math]::Max(0, $zero - 1))]
    }
    $sections += [pscustomobject]@{
        Name = [Text.Encoding]::ASCII.GetString($nameBytes)
        VirtualSize = [BitConverter]::ToUInt32($source, $offset + 8)
        VirtualAddress = [BitConverter]::ToUInt32($source, $offset + 12)
        RawSize = [BitConverter]::ToUInt32($source, $offset + 16)
        RawAddress = [BitConverter]::ToUInt32($source, $offset + 20)
    }
}

$control = $sections | Where-Object Name -eq '.nvFatBi' | Select-Object -First 1
$fatSection = $sections | Where-Object Name -eq '.nv_fatb' | Select-Object -First 1
if (-not $control -or -not $fatSection) {
    throw 'CUDA fatbin sections were not found'
}

$payloadSize = [UInt64] 0
foreach ($replacement in $replacements) {
    $payloadSize = Align-Up $payloadSize 256
    $replacement | Add-Member -NotePropertyName PayloadOffset -NotePropertyValue $payloadSize
    $payloadSize += $replacement.Image.Length

    $wrapperOffset = [int] ($control.RawAddress + 24*($replacement.Wrapper - 1))
    if ([BitConverter]::ToUInt32($source, $wrapperOffset) -ne 0x466243b1) {
        throw "Wrapper $($replacement.Wrapper) has an invalid magic"
    }
    $oldPointer = [BitConverter]::ToUInt64($source, $wrapperOffset + 8)
    $oldRva = $oldPointer - $imageBase
    if ($oldRva -lt $fatSection.VirtualAddress -or
        $oldRva -ge $fatSection.VirtualAddress + $fatSection.VirtualSize) {
        throw "Wrapper $($replacement.Wrapper) does not point into the original .nv_fatb"
    }
    $oldRaw = [int] ($fatSection.RawAddress + $oldRva - $fatSection.VirtualAddress)
    if ([BitConverter]::ToUInt32($source, $oldRaw) -ne 3126193488) {
        throw "Wrapper $($replacement.Wrapper) does not point to a fatbin header"
    }
    $replacement | Add-Member -NotePropertyName WrapperOffset -NotePropertyValue $wrapperOffset
}

$lastEnd = [UInt64] 0
foreach ($section in $sections) {
    $end = [UInt64] $section.VirtualAddress +
        [Math]::Max([UInt64] $section.VirtualSize, [UInt64] $section.RawSize)
    if ($end -gt $lastEnd) {
        $lastEnd = $end
    }
}

$newVirtualAddress = [UInt32] (Align-Up $lastEnd $sectionAlignment)
$newRawAddress = [UInt32] (Align-Up $source.Length $fileAlignment)
$newRawSize = [UInt32] (Align-Up $payloadSize $fileAlignment)
$newSizeOfImage = [UInt32] (Align-Up ($newVirtualAddress + $payloadSize) $sectionAlignment)
$output = New-Object byte[] ([int] ($newRawAddress + $newRawSize))
$source.CopyTo($output, 0)

foreach ($replacement in $replacements) {
    $raw = [int] ($newRawAddress + $replacement.PayloadOffset)
    $replacement.Image.CopyTo($output, $raw)
    Put-U64 $output ($replacement.WrapperOffset + 8) (
        [UInt64] ($imageBase + $newVirtualAddress + $replacement.PayloadOffset))
}

[Text.Encoding]::ASCII.GetBytes('.optfat').CopyTo($output, $newHeader)
Put-U32 $output ($newHeader + 8) ([UInt32] $payloadSize)
Put-U32 $output ($newHeader + 12) $newVirtualAddress
Put-U32 $output ($newHeader + 16) $newRawSize
Put-U32 $output ($newHeader + 20) $newRawAddress
Put-U32 $output ($newHeader + 36) 0x40000040

Put-U16 $output ($coff + 2) ([UInt16] ($sectionCount + 1))
Put-U32 $output ($optional + 8) ([UInt32] (
    [BitConverter]::ToUInt32($output, $optional + 8) + $newRawSize))
Put-U32 $output ($optional + 56) $newSizeOfImage
[IO.File]::WriteAllBytes($OutputDll, $output)

[pscustomobject]@{
    input = $InputDll
    output = $OutputDll
    wrappers = ($replacements.Wrapper -join ',')
    payload_bytes = $payloadSize
    output_bytes = $output.Length
}
