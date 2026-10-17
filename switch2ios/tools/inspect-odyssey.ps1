# Extract and inspect owned Odyssey NSP locally. Never upload game files or prod.keys.
param(
    [Parameter(Mandatory=$true)][string]$Base,
    [Parameter(Mandatory=$true)][string]$Keys,
    [string]$Update = "",
    [string]$Output = "switch2ios/local-work/odyssey",
    [switch]$Rewrite
)
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Push-Location $repo
try {
    foreach ($path in @($Base, $Keys)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "File not found: $path" }
    }
    if ($Update -and -not (Test-Path -LiteralPath $Update -PathType Leaf)) { throw "Update not found" }
    $basePath = (Resolve-Path -LiteralPath $Base).Path
    $keyPath = (Resolve-Path -LiteralPath $Keys).Path
    $updPath = if ($Update) { (Resolve-Path -LiteralPath $Update).Path } else { "" }
    $out = [System.IO.Path]::GetFullPath((Join-Path $repo $Output))
    New-Item -ItemType Directory -Force -Path $out | Out-Null

    & cargo build --release -p nxfs
    if ($LASTEXITCODE -ne 0) { throw "nxfs compilation failed" }
    $suffix = if ($IsWindows) { ".exe" } else { "" }
    $nxfs = Join-Path $repo ("target/release/nxfs" + $suffix)
    $inspectArgs = @("--keys", $keyPath, "info", $basePath)
    if ($updPath) { $inspectArgs += $updPath }
    & $nxfs @inspectArgs
    if ($LASTEXITCODE -ne 0) { throw "NSP inspection failed" }
    $extractArgs = @("--keys", $keyPath, "extract", "--base", $basePath, "--out", $out)
    if ($updPath) { $extractArgs += @("--update", $updPath) }
    & $nxfs @extractArgs
    if ($LASTEXITCODE -ne 0) { throw "Private ExeFS extraction failed" }

    $report = Join-Path $out "native-preflight.json"
    $argsToPython = @((Join-Path $repo "switch2ios/tools/native_preflight.py"),
        "--exefs", $out, "--report", $report)
    if ($Rewrite) {
        & cargo build --release -p nxpatch
        if ($LASTEXITCODE -ne 0) { throw "nxpatch compilation failed" }
        $argsToPython += @("--rewrite", "--nxpatch",
            (Join-Path $repo ("target/release/nxpatch" + $suffix)),
            "--patched-out", (Join-Path $out "private-patched"))
    }
    & python @argsToPython
    if ($LASTEXITCODE -ne 0) { throw "Preflight returned code $LASTEXITCODE" }
    Write-Host "Safe to review and share: $report"
    Write-Host "Keep the NSP, keys, extracted and patched game code private."
} finally {
    Pop-Location
}
