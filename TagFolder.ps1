param([string]$dir)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($dir) -or -not (Test-Path -LiteralPath $dir)) { exit }

# ===== 1. 다중 선택 취합 =====
$listFile = Join-Path $env:TEMP "TagFolder_selection.lst"

# 내 경로를 공유 파일에 추가 (동시 접근 경합 대비 재시도)
for ($i = 0; $i -lt 30; $i++) {
    try {
        $fs = [System.IO.File]::Open($listFile, 'Append', 'Write', 'None')
        $sw = New-Object System.IO.StreamWriter($fs, [System.Text.Encoding]::UTF8)
        $sw.WriteLine($dir); $sw.Close()
        break
    } catch { Start-Sleep -Milliseconds 30 }
}

# 마스터 선출: 뮤텍스를 처음 만든 인스턴스만 계속 진행
$created = $false
$mutex = New-Object System.Threading.Mutex($true, "TagFolderSingleInstance", [ref]$created)
if (-not $created) { exit }   # 이미 마스터가 있으면 조용히 종료

# 다른 인스턴스들이 경로를 다 쓸 때까지 대기 (파일 크기 안정화 감지)
$prev = -1
do {
    Start-Sleep -Milliseconds 250
    $size = (Get-Item -LiteralPath $listFile).Length
    if ($size -eq $prev) { break }
    $prev = $size
} while ($true)

$dirs = @(Get-Content -LiteralPath $listFile -Encoding UTF8 |
          Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
          Select-Object -Unique)
Remove-Item -LiteralPath $listFile -Force -ErrorAction SilentlyContinue
if ($dirs.Count -eq 0) { exit }

# ===== 2. 기존 태그 읽기 (첫 번째 폴더 기준) =====
function Get-FolderTag([string]$d) {
    $ini = Join-Path $d "desktop.ini"
    if (Test-Path -LiteralPath $ini) {
        $raw = Get-Content -LiteralPath $ini -Encoding Default -Raw
        if ($raw) {
            $m = [regex]::Match($raw, 'Prop5=31,([^\r\n]*)')
            if ($m.Success) { return $m.Groups[1].Value }
        }
    }
    return ""
}

$currentTag = Get-FolderTag $dirs[0]
$hasTag = ($dirs | Where-Object { (Get-FolderTag $_) -ne "" }).Count -gt 0

# ===== 3. GUI (한 번만) =====
$form = New-Object Windows.Forms.Form
$label = New-Object Windows.Forms.Label
$textbox = New-Object Windows.Forms.TextBox
$button = New-Object Windows.Forms.Button
$clearButton = New-Object Windows.Forms.Button
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object Drawing.Size(240,150)
$form.Text = "Tag Folder"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.AcceptButton = $button
$form.TopMost = $true
$label.Location = New-Object Drawing.Point(20,20)
$label.Size = New-Object Drawing.Size(180,23)
$label.Text = if ($dirs.Count -gt 1) { "Enter your tag ($($dirs.Count)개 폴더)" } else { "Enter your tag" }
$textbox.Location = New-Object Drawing.Point(20,43)
$textbox.Size = New-Object Drawing.Size(180,23)
$textbox.Text = $currentTag
$button.Location = New-Object Drawing.Point(160,76)
$button.Size = New-Object Drawing.Size(50,23)
$button.Text = "OK"
$button.DialogResult = "OK"
$button.Add_Click({$form.Close()})

$script:doClear = $false
if ($hasTag) {
    $clearButton.Location = New-Object Drawing.Point(20,76)
    $clearButton.Size = New-Object Drawing.Size(60,23)
    $clearButton.Text = "Clear"
    $clearButton.Add_Click({
        $script:doClear = $true
        $form.DialogResult = "OK"
        $form.Close()
    })
    $form.Controls.Add($clearButton)
}

$form.Controls.Add($label)
$form.Controls.Add($textbox)
$form.Controls.Add($button)
$form.Add_Shown({$form.Activate(); $textbox.Focus(); $textbox.SelectAll()})
$null = $form.ShowDialog()

if ($form.DialogResult -ne [System.Windows.Forms.DialogResult]::OK) { $mutex.ReleaseMutex(); exit }

if ($script:doClear) { $tag = "" }
else {
    $tag = $textbox.Text.Trim()
    if ($tag -eq "") { $mutex.ReleaseMutex(); exit }
}

# ===== 4. 모든 폴더에 적용 =====
function Set-FolderTag([string]$d, [string]$tag) {
    $ini = Join-Path $d "desktop.ini"

    $keep = @()
    if (Test-Path -LiteralPath $ini) {
        attrib -h -s "$ini"
        $keep = @(Get-Content -LiteralPath $ini -Encoding Default | Where-Object {
            $_ -notmatch 'F29F85E0' -and $_ -notmatch '^Prop5='
        })
    }

    $out = @()
    $out += $keep
    if ($tag -ne "") {
        $out += '[{F29F85E0-4FF9-1068-AB91-08002B27B3D9}]'
        $out += "Prop5=31,$tag"
    }

    # 폴더마다 고유 임시 폴더 사용 (MoveHere 충돌 방지)
    $tmpDir = Join-Path $env:TEMP ("tagtmp_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    $tmp = Join-Path $tmpDir "desktop.ini"
    [System.IO.File]::WriteAllLines($tmp, [string[]]$out, [System.Text.Encoding]::Default)

    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.NameSpace($d)
    $folder.MoveHere($tmp, 4 + 16 + 1024)
    Start-Sleep -Milliseconds 300
    Remove-Item -LiteralPath $tmpDir -Force -Recurse -ErrorAction SilentlyContinue

    attrib +h +s "$ini"
    $di = Get-Item -LiteralPath $d -Force
    $di.Attributes = $di.Attributes -bor [System.IO.FileAttributes]::System
}

try {
    foreach ($d in $dirs) { Set-FolderTag $d $tag }
}
catch {
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message + [Environment]::NewLine + $_.ScriptStackTrace, "ERROR") | Out-Null
}
finally {
    $mutex.ReleaseMutex()
}