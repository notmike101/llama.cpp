param(
    [Parameter(Mandatory = $true)][string] $InputPtx,
    [Parameter(Mandatory = $true)][string] $OutputPtx,
    [ValidateSet('both', 'first', 'last')][string] $Selection = 'both'
)

$ErrorActionPreference = 'Stop'

$entry = '.entry _Z17mul_mat_vec_q_moeIL9ggml_type18ELi1ELb1'
$text = [IO.File]::ReadAllText($InputPtx)
$start = $text.LastIndexOf($entry, [StringComparison]::Ordinal)
$end = $text.IndexOf("`n.entry ", $start + $entry.Length, [StringComparison]::Ordinal)
if ($start -lt 0 -or $end -lt 0) {
    throw 'IQ3_S MoE entry boundary was not found'
}

$prefix = $text.Substring(0, $start)
$kernel = $text.Substring($start, $end - $start)
$suffix = $text.Substring($end)
$allLoads = @(
    'ld.global.nc.u32 %r26, [%rd24];',
    'ld.global.nc.u32 %r138, [%rd45];'
)
$loads = switch ($Selection) {
    'first' { @($allLoads[0]) }
    'last'  { @($allLoads[1]) }
    default { $allLoads }
}
foreach ($load in $loads) {
    if (($kernel.Split($load).Count - 1) -ne 1) {
        throw "Expected one load: $load"
    }
    $kernel = $kernel.Replace($load, $load.Replace('.nc.u32', '.nc.L2::128B.u32'))
}

[IO.File]::WriteAllText($OutputPtx, $prefix + $kernel + $suffix)

[pscustomobject]@{
    input = $InputPtx
    output = $OutputPtx
    patched_instructions = $loads.Count
}
