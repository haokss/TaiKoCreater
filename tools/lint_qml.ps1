<#
.SYNOPSIS
    QML 静态检查（qmllint）+ 基线比对。

.DESCRIPTION
    对 main.qml 与 ui/ 下所有 QML 跑 qmllint，并与 tools/qmllint-baseline.json 比对：
    只对"新增"问题返回失败，历史遗留问题不会挡住构建。
    修完历史问题后用 -UpdateBaseline 更新基线，防止回退。

    注意：info 级（如 unqualified / Quick.color，因本项目大量使用 context property 而必然出现）
    不计入基线，也不影响退出码。

.PARAMETER Root
    项目根目录，默认脚本所在目录的上一级。

.PARAMETER UpdateBaseline
    把当前结果写回基线文件后退出。

.PARAMETER Strict
    不比对基线，任何 warning 都算失败。

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\lint_qml.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\lint_qml.ps1 -UpdateBaseline
#>
param(
    [string]$Root = "",
    [switch]$UpdateBaseline,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"

if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
$Root = (Resolve-Path $Root).Path
$BaselinePath = Join-Path $Root "tools\qmllint-baseline.json"

function Find-Qmllint {
    $cmd = Get-Command qmllint -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $bases = @($env:QTDIR, "E:\Qt", "C:\Qt", "D:\Qt") | Where-Object { $_ -and (Test-Path $_) }
    foreach ($base in $bases) {
        $hit = Get-ChildItem $base -Recurse -Filter "qmllint.exe" -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Get-RelativePath([string]$base, [string]$full) {
    $b = $base.Replace('\', '/').TrimEnd('/')
    $f = $full.Replace('\', '/')
    if ($f.StartsWith($b, [StringComparison]::OrdinalIgnoreCase)) {
        return $f.Substring($b.Length).TrimStart('/')
    }
    return $f
}

# ── 定位 qmllint ──
$qmllint = Find-Qmllint
if (-not $qmllint) {
    Write-Host "[lint] 未找到 qmllint（Qt6 自带，通常在 <Qt>/<ver>/msvc2022_64/bin）" -ForegroundColor Yellow
    Write-Host "[lint] 已跳过 QML 检查" -ForegroundColor Yellow
    exit 0
}

# ── 收集文件 ──
$files = @()
$mainQml = Join-Path $Root "main.qml"
if (Test-Path $mainQml) { $files += (Resolve-Path $mainQml).Path }
$uiDir = Join-Path $Root "ui"
if (Test-Path $uiDir) {
    $files += (Get-ChildItem $uiDir -Recurse -Filter "*.qml" | ForEach-Object { $_.FullName })
}
if ($files.Count -eq 0) {
    Write-Host "[lint] 没有找到 QML 文件" -ForegroundColor Yellow
    exit 0
}

# ── 运行 qmllint（配置取自项目根的 .qmllint.ini）──
$jsonPath = Join-Path $env:TEMP ("qmllint_" + [guid]::NewGuid().ToString("N") + ".json")
Push-Location $Root
try {
    & $qmllint -I $Root --json $jsonPath -- $files 2>$null | Out-Null
    $lintExit = $LASTEXITCODE
}
finally {
    Pop-Location
}

if (-not (Test-Path $jsonPath)) {
    Write-Host "[lint] qmllint 未产出结果（退出码 $lintExit）" -ForegroundColor Red
    exit 1
}

$doc = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
Remove-Item $jsonPath -Force -ErrorAction SilentlyContinue

# ── 展开成记录 ──
$records = @()
foreach ($fileEntry in @($doc.files)) {
    if (-not $fileEntry) { continue }
    $rel = Get-RelativePath $Root $fileEntry.filename
    foreach ($w in @($fileEntry.warnings)) {
        if (-not $w) { continue }
        $records += [pscustomobject]@{
            File    = $rel
            Line    = [int]$w.line
            Column  = [int]$w.column
            Id      = [string]$w.id
            Type    = [string]$w.type
            Message = [string]$w.message
        }
    }
}

$errors  = @($records | Where-Object { $_.Type -eq "error" })
$tracked = @($records | Where-Object { $_.Type -ne "info" })
$infos   = @($records | Where-Object { $_.Type -eq "info" })

# ── 当前计数（仅 warning/error）──
$counts = @{}
foreach ($r in $tracked) {
    $key = "$($r.File)|$($r.Id)"
    if ($counts.ContainsKey($key)) { $counts[$key] = $counts[$key] + 1 }
    else { $counts[$key] = 1 }
}

Write-Host ""
Write-Host ("[lint] QML 静态检查：{0} 个文件" -f $files.Count) -ForegroundColor Cyan
foreach ($g in ($tracked | Group-Object Id | Sort-Object Count -Descending)) {
    Write-Host ("        {0,-28} {1,4}" -f $g.Name, $g.Count)
}
Write-Host ("        需处理 {0} 条，另 {1} 条 info 级（context property 等已知误报），{2} 个语法错误" -f `
    $tracked.Count, $infos.Count, $errors.Count)

# ── 错误优先 ──
if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "[lint] 语法/硬错误：" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host ("  {0}:{1}  [{2}] {3}" -f $e.File, $e.Line, $e.Id, $e.Message) -ForegroundColor Red
    }
    exit 1
}

# ── 更新基线 ──
if ($UpdateBaseline) {
    $obj = [ordered]@{
        revision  = 2
        generated = (Get-Date).ToString("s")
        note      = "历史遗留问题基线：修完后用 -UpdateBaseline 降低计数，防止回退"
        counts    = $counts
    }
    $obj | ConvertTo-Json -Depth 4 | Set-Content $BaselinePath -Encoding UTF8
    Write-Host "[lint] 已更新基线: $BaselinePath" -ForegroundColor Green
    exit 0
}

if ($Strict) {
    if ($tracked.Count -gt 0) {
        Write-Host "[lint] -Strict 模式：存在 $($tracked.Count) 条问题" -ForegroundColor Red
        exit 1
    }
    Write-Host "[lint] 通过（无问题）" -ForegroundColor Green
    exit 0
}

# ── 基线比对 ──
$base = @{}
if (Test-Path $BaselinePath) {
    $baseDoc = Get-Content $BaselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($baseDoc.counts) {
        foreach ($prop in $baseDoc.counts.PSObject.Properties) {
            $base[$prop.Name] = [int]$prop.Value
        }
    }
}
else {
    Write-Host "[lint] 未找到基线文件，首次运行请执行 -UpdateBaseline" -ForegroundColor Yellow
}

$regressions = @()
foreach ($key in $counts.Keys) {
    $was = 0
    if ($base.ContainsKey($key)) { $was = $base[$key] }
    if ($counts[$key] -gt $was) {
        $parts = $key -split '\|'
        $regressions += [pscustomobject]@{
            File = $parts[0]
            Id   = $parts[1]
            Was  = $was
            Now  = $counts[$key]
        }
    }
}

$improved = 0
foreach ($key in $base.Keys) {
    $now = 0
    if ($counts.ContainsKey($key)) { $now = $counts[$key] }
    if ($now -lt $base[$key]) { $improved++ }
}

if ($regressions.Count -eq 0) {
    if ($improved -gt 0) {
        Write-Host ("[lint] 通过：无新增问题，且有 {0} 项优于基线，建议 -UpdateBaseline 固化" -f $improved) -ForegroundColor Green
    }
    else {
        Write-Host "[lint] 通过：无新增问题" -ForegroundColor Green
    }
    exit 0
}

Write-Host ""
Write-Host "[lint] 发现新增问题（可能导致 QML 运行期报错）：" -ForegroundColor Red
foreach ($r in $regressions) {
    Write-Host ("  {0}  [{1}] {2} -> {3}" -f $r.File, $r.Id, $r.Was, $r.Now) -ForegroundColor Red
    $tracked | Where-Object { $_.File -eq $r.File -and $_.Id -eq $r.Id } |
        Select-Object -First 3 |
        ForEach-Object {
            Write-Host ("      {0}:{1}  {2}" -f $_.File, $_.Line, $_.Message) -ForegroundColor DarkGray
        }
}
Write-Host ""
Write-Host "[lint] 修复后重跑；确认可接受则执行 -UpdateBaseline" -ForegroundColor Yellow
exit 1
