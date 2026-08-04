param(
    [Parameter(Mandatory = $true)][string] $InputDll,
    [Parameter(Mandatory = $true)][string] $OutputFatbin,
    [ValidateRange(1, 4096)][int] $WrapperIndex
)

$ErrorActionPreference = 'Stop'
$source = [IO.File]::ReadAllBytes($InputDll)
$peOffset = [BitConverter]::ToInt32($source, 0x3c)
$coff = $peOffset + 4
$sectionCount = [BitConverter]::ToUInt16($source, $coff + 2)
$optionalSize = [BitConverter]::ToUInt16($source, $coff + 16)
$optional = $coff + 20
$imageBase = [BitConverter]::ToUInt64($source, $optional + 24)
$sectionTable = $optional + $optionalSize

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
if (-not $control) {
    throw 'CUDA fatbin control section was not found'
}

$wrapperOffset = [int] ($control.RawAddress + 24*($WrapperIndex - 1))
if ([BitConverter]::ToUInt32($source, $wrapperOffset) -ne 0x466243b1) {
    throw "Wrapper $WrapperIndex has an invalid magic"
}

$pointer = [BitConverter]::ToUInt64($source, $wrapperOffset + 8)
$rva = $pointer - $imageBase
$target = $sections | Where-Object {
    $rva -ge $_.VirtualAddress -and
    $rva -lt $_.VirtualAddress + $_.VirtualSize
} | Select-Object -First 1
if (-not $target) {
    throw "Wrapper $WrapperIndex does not point into a section"
}

$rawOffset = [int] ($target.RawAddress + $rva - $target.VirtualAddress)
if ([BitConverter]::ToUInt32($source, $rawOffset) -ne 3126193488) {
    throw "Wrapper $WrapperIndex does not point to a fatbin header"
}

$imageSize = 16 + [BitConverter]::ToUInt64($source, $rawOffset + 8)
$targetEnd = [UInt64]$target.RawAddress + $target.RawSize
if ([UInt64]$rawOffset + $imageSize -gt $targetEnd -or
        [UInt64]$rawOffset + $imageSize -gt $source.Length) {
    throw "Wrapper $WrapperIndex fatbin extends beyond its section"
}

$image = New-Object byte[] $imageSize
[Array]::Copy($source, $rawOffset, $image, 0, $image.Length)
[IO.File]::WriteAllBytes($OutputFatbin, $image)

[pscustomobject]@{
    wrapper = $WrapperIndex
    section = $target.Name
    bytes = $image.Length
    output = $OutputFatbin
}
