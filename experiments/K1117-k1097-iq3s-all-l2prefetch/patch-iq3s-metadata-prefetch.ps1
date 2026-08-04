param(
    [Parameter(Mandatory = $true)][string] $InputPtx,
    [Parameter(Mandatory = $true)][string] $OutputPtx
)

$ErrorActionPreference = 'Stop'

$entry = '.entry _Z17mul_mat_vec_q_moeIL9ggml_type18ELi1ELb1'
$text = [IO.File]::ReadAllText($InputPtx)
$start = $text.LastIndexOf($entry, [StringComparison]::Ordinal)
if ($start -lt 0) {
    throw 'IQ3_S MoE entry was not found'
}
$end = $text.IndexOf("`n.entry ", $start + $entry.Length, [StringComparison]::Ordinal)
if ($end -lt 0) {
    throw 'Entry boundary was not found'
}

$prefix = $text.Substring(0, $start)
$kernel = $text.Substring($start, $end - $start)
$suffix = $text.Substring($end)
$before = ([regex]::Matches($kernel, 'ld\.global\.nc\.u16')).Count
$kernel = $kernel.Replace('ld.global.nc.u16', 'ld.global.nc.L2::128B.u16')
$after = ([regex]::Matches($kernel, 'ld\.global\.nc\.L2::128B\.u16')).Count
if ($before -ne 7 -or $after -ne 7) {
    throw "Expected 7 IQ3_S noncoherent metadata loads, found $before"
}

[IO.File]::WriteAllText($OutputPtx, $prefix + $kernel + $suffix)

[pscustomobject]@{
    input = $InputPtx
    output = $OutputPtx
    patched_instructions = $after
}
