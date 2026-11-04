<#
verify_win.ps1 — L2 外部验证包 / Windows 字节级复算
只按 MANIFEST.sha256 逐行重算 SHA-256；不下 L2 结论、不改 layer_B、不签回执、不建占位文件。
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = 'Stop'
$Utf8Bom = New-Object System.Text.UTF8Encoding($true)
$script:lines = @()

function W { param([string]$s) Write-Host $s; $script:lines += $s }

$root     = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd('\')
$manifest = Join-Path $root 'MANIFEST.sha256'
$outPath  = Join-Path $root 'verify_result.txt'

if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    Write-Host 'ERROR: MANIFEST.sha256 NOT FOUND'
    exit 2
}

W '# verify_result.txt'
W 'scope: operation_layer_hash_recheck_only'
W 'this_is_not: L2 approval / independent_review PASS / baseline_record_corrected'
W 'independent_review: PENDING'
W 'approval: PENDING'
W 'layer_A: PENDING'
W 'layer_B: NOT_COVERED'
W 'reason_layer_B: original_stdout_missing_no_rerun'
W ('generated_at: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
W '---'

$raw  = Get-Content -LiteralPath $manifest -Encoding UTF8
$rows = @($raw | Where-Object { $_ -match '^[0-9a-fA-F]{64}  ' })

$nTotal = 0; $nMatch = 0; $nFail = 0; $nMissing = 0

foreach ($r in $rows) {
    $expected = $r.Substring(0, 64)
    $rel      = $r.Substring(66).Trim()
    $full     = Join-Path $root ($rel -replace '/', '\')
    $nTotal++
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        W ("MISSING   " + $rel)
        $nMissing++
        continue
    }
    $actual = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    if ($actual -ieq $expected) {
        W ("MATCH     " + $rel)
        $nMatch++
    } else {
        W ("MISMATCH  " + $rel + "  expected=" + $expected + "  actual=" + $actual)
        $nFail++
    }
}

W '---'
W ("total: " + $nTotal + "  match: " + $nMatch + "  mismatch: " + $nFail + "  missing: " + $nMissing)

if ($rows.Count -eq 0) {
    W 'hash_check: NOT_EVALUATED'
    W 'reason: MANIFEST.sha256 has no valid hash rows'
} elseif (($nFail -eq 0) -and ($nMissing -eq 0) -and ($nMatch -eq $nTotal)) {
    W 'hash_check: PASSED'
} else {
    W 'hash_check: FAILED'
}

W 'note: hash_check PASSED only means bytes survived upload. It does NOT mean layer_A PASS, layer_B covered, or L2 approved.'
W 'disclaimer: 本复核仅代表操作层面的代码运行一致，不代表对项目商业价值的背书；不代表与原始运行输出一致（层 B 未覆盖）。您可以匿名或使用代号。'

# 空白回执副本：只复制，不预填任何字段，不建占位内容
$tmpl  = Join-Path $root '03_任务书与回执\review_receipt_v1.0.yaml'
$blank = Join-Path $root '回执_待填.yaml'
if ((Test-Path -LiteralPath $tmpl -PathType Leaf) -and (-not (Test-Path -LiteralPath $blank))) {
    Copy-Item -LiteralPath $tmpl -Destination $blank
    W 'receipt: 回执_待填.yaml (blank copy, fill by human reviewer)'
} else {
    W 'receipt: TEMPLATE_NOT_FOUND_OR_ALREADY_EXISTS (no placeholder created)'
}

$text = ($script:lines -join "`n") -replace "`r`n", "`n"
$text = $text -replace "`n", "`r`n"
[IO.File]::WriteAllText($outPath, ($text + "`r`n"), $Utf8Bom)
Write-Host ("`nWROTE " + $outPath)

if (($nFail -gt 0) -or ($nMissing -gt 0)) { exit 1 } else { exit 0 }
