param(
    [Parameter(Mandatory = $true)][string] $InputPtx,
    [Parameter(Mandatory = $true)][string] $OutputPtx,
    [ValidateSet(64, 128, 256)][int] $PrefetchBytes = 128,
    [ValidateSet('weights', 'activations', 'all')][string] $Selection = 'weights'
)

$ErrorActionPreference = 'Stop'

$entry = '.entry _Z17mul_mat_vec_q_moeIL9ggml_type23ELi1ELb1'
$text = [IO.File]::ReadAllText($InputPtx)
$start = $text.LastIndexOf($entry, [StringComparison]::Ordinal)
$end = $text.IndexOf("`n.entry ", $start + $entry.Length, [StringComparison]::Ordinal)
if ($start -lt 0 -or $end -lt 0) {
    throw 'IQ4_XS MoE entry boundary was not found'
}

$prefix = $text.Substring(0, $start)
$kernel = $text.Substring($start, $end - $start)
$suffix = $text.Substring($end)
$hint = "L2::$($PrefetchBytes)B"
$weightPatterns = @(
    @{ Old = 'ld.global.nc.u32 %r108, [%rd39+-4];'; New = "ld.global.nc.$hint.u32 %r108, [%rd39+-4];" },
    @{ Old = 'ld.global.nc.u32 %r129, [%rd39];';    New = "ld.global.nc.$hint.u32 %r129, [%rd39];" },
    @{ Old = 'ld.global.nc.u32 %r144, [%rd39+4];';  New = "ld.global.nc.$hint.u32 %r144, [%rd39+4];" },
    @{ Old = 'ld.global.nc.u32 %r159, [%rd39+8];';  New = "ld.global.nc.$hint.u32 %r159, [%rd39+8];" },
    @{ Old = 'ld.global.u32 %r183, [%rd42+-4];';    New = "ld.global.$hint.u32 %r183, [%rd42+-4];" },
    @{ Old = 'ld.global.u32 %r198, [%rd42];';       New = "ld.global.$hint.u32 %r198, [%rd42];" },
    @{ Old = 'ld.global.u32 %r213, [%rd42+4];';     New = "ld.global.$hint.u32 %r213, [%rd42+4];" },
    @{ Old = 'ld.global.u32 %r228, [%rd42+8];';     New = "ld.global.$hint.u32 %r228, [%rd42+8];" }
)
$activationPatterns = @(
    @{ Old = 'ld.global.nc.u32 %r107, [%rd48+-16];'; New = "ld.global.nc.$hint.u32 %r107, [%rd48+-16];" },
    @{ Old = 'ld.global.nc.u32 %r44, [%rd48+-12];';  New = "ld.global.nc.$hint.u32 %r44, [%rd48+-12];" },
    @{ Old = 'ld.global.nc.u32 %r85, [%rd48+-8];';   New = "ld.global.nc.$hint.u32 %r85, [%rd48+-8];" },
    @{ Old = 'ld.global.nc.u32 %r93, [%rd48+-4];';   New = "ld.global.nc.$hint.u32 %r93, [%rd48+-4];" },
    @{ Old = 'ld.global.nc.u32 %r101, [%rd48];';     New = "ld.global.nc.$hint.u32 %r101, [%rd48];" },
    @{ Old = 'ld.global.nc.u32 %r48, [%rd48+4];';    New = "ld.global.nc.$hint.u32 %r48, [%rd48+4];" },
    @{ Old = 'ld.global.nc.u32 %r89, [%rd48+8];';    New = "ld.global.nc.$hint.u32 %r89, [%rd48+8];" },
    @{ Old = 'ld.global.nc.u32 %r97, [%rd48+12];';   New = "ld.global.nc.$hint.u32 %r97, [%rd48+12];" },
    @{ Old = 'ld.global.nc.u32 %r105, [%rd48+16];';  New = "ld.global.nc.$hint.u32 %r105, [%rd48+16];" }
)
$patterns = switch ($Selection) {
    'activations' { $activationPatterns }
    'all'         { $weightPatterns + $activationPatterns }
    default       { $weightPatterns }
}
foreach ($pattern in $patterns) {
    if (($kernel.Split($pattern.Old).Count - 1) -ne 1) {
        throw "Expected one load: $($pattern.Old)"
    }
    $kernel = $kernel.Replace($pattern.Old, $pattern.New)
}

[IO.File]::WriteAllText($OutputPtx, $prefix + $kernel + $suffix)

[pscustomobject]@{
    input = $InputPtx
    output = $OutputPtx
    prefetch_bytes = $PrefetchBytes
    selection = $Selection
    patched_instructions = $patterns.Count
}
