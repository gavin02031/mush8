# Offline Windows proof-of-concept for owned Odyssey NSP dumps.
# No keys or copyrighted files are uploaded or added to the repository.
param(
    [Parameter(Mandatory = $true)][string]$Base,
    [Parameter(Mandatory = $true)][string]$Keys,
    [string]$Update = "",
    [string]$Output = "switch2ios/local-work/odyssey"
)
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Push-Location $repo
try {
    foreach ($file in @($Base, $Keys)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "File not found: $file" }
    }
    if ($Update -and -not (Test-Path -LiteralPath $Update -PathType Leaf)) { throw "Update not found: $Update" }

    $basePath = (Resolve-Path -LiteralPath $Base).Path
    $keysPath = (Resolve-Path -LiteralPath $Keys).Path
    $updatePath = if ($Update) { (Resolve-Path -LiteralPath $Update).Path } else { "" }
    $outPath = [System.IO.Path]::GetFullPath((Join-Path $repo $Output))
    New-Item -ItemType Directory -Path $outPath -Force | Out-Null

    Write-Host "Building nxfs, the game-file inspection tool..."
    & cargo build --release -p nxfs
    if ($LASTEXITCODE -ne 0) { throw "nxfs build failed" }
    $nxfs = Join-Path $repo "target/release/nxfs.exe"
    if (-not (Test-Path $nxfs)) { $nxfs = Join-Path $repo "target/release/nxfs" }
    if (-not (Test-Path $nxfs)) { throw "nxfs binary not found" }

    Write-Host "Inspecting locally (do not publish extracted files)..."
    $infoArgs = @("--keys", $keysPath, "info", $basePath)
    if ($updatePath) { $infoArgs += $updatePath }
    & $nxfs @infoArgs
    if ($LASTEXITCODE -ne 0) { throw "NSP info failed" }

    Write-Host "Extracting ExeFS and control metadata to: $outPath"
    $extractArgs = @("--keys", $keysPath, "extract", "--base", $basePath, "--out", $outPath)
    if ($updatePath) { $extractArgs += @("--update", $updatePath) }
    & $nxfs @extractArgs
    if ($LASTEXITCODE -ne 0) { throw "ExeFS extraction failed" }

    $exefs = Join-Path $outPath "exefs"
    if (-not (Test-Path -LiteralPath $exefs)) { throw "Expected ExeFS folder missing" }
    $files = @(Get-ChildItem -LiteralPath $exefs -File | ForEach-Object {
        $moduleId = $null
        if ($_.Name -eq "main" -or $_.Name -eq "sdk" -or $_.Name -match '^subsdk[0-9]+
    })
    $manifest = [pscustomobject]@{
        target = "Super Mario Odyssey - manual validation required"
        source = "Local user-provided dump; no game binaries in git"
        modules = $files
    }
    $manifestPath = Join-Path $outPath "exefs-manifest.json"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Host "Wrote local module manifest: $manifestPath"
    Write-Host "Modules found: $($files.Count). Next: identify title SDK and patch support."
} finally {
    Pop-Location
}
) {
            $nsoInfo = & $nxfs nso $_.FullName 2>&1
            if ($LASTEXITCODE -eq 0) {
                $idLine = @($nsoInfo | Where-Object { $_ -match '^module id ([0-9a-fA-F]+)' } | Select-Object -First 1)
                if ($idLine.Count -gt 0) { $moduleId = ([string]$idLine[0] -replace '^module id ', '') }
            } else {
                Write-Warning "Could not parse NSO module: $($_.Name)"
            }
        }
        [pscustomobject]@{
            name = $_.Name
            size_bytes = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            module_id = $moduleId
        }
    })
    $manifest = [pscustomobject]@{
        target = "Super Mario Odyssey - manual validation required"
        source = "Local user-provided dump; no game binaries in git"
        modules = $files
    }
    $manifestPath = Join-Path $outPath "exefs-manifest.json"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Host "Wrote local module manifest: $manifestPath"
    Write-Host "Modules found: $($files.Count). Next: identify title SDK and patch support."
} finally {
    Pop-Location
}
