# Run after Godot web export. A content-addressed package cannot reuse stale PCK cache.
$projectRoot = Split-Path $PSScriptRoot -Parent
$docsRoot = Join-Path $projectRoot 'docs'
$package = Join-Path $docsRoot 'index.pck'
$digest = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.Substring(0, 12).ToLowerInvariant()
$name = 'game-' + $digest + '.pck'
Copy-Item -LiteralPath $package -Destination (Join-Path $docsRoot $name) -Force
$htmlPath = Join-Path $docsRoot 'index.html'
$html = [IO.File]::ReadAllText($htmlPath)
$insertion = 'GODOT_CONFIG.mainPack = "' + $name + '"; GODOT_CONFIG.fileSizes["' + $name + '"] = GODOT_CONFIG.fileSizes["index.pck"];'
$html = $html.Replace('const engine = new Engine(GODOT_CONFIG);', $insertion + "`nconst engine = new Engine(GODOT_CONFIG);")
[IO.File]::WriteAllText($htmlPath, $html, [Text.UTF8Encoding]::new($false))
Write-Output $name
