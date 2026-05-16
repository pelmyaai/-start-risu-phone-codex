$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Target = Join-Path $ScriptDir "RisuAI-Phone-Codex.cmd"
$Desktop = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $Desktop "RisuAI 폰 연결 시작.lnk"

if (-not (Test-Path -LiteralPath $Target)) {
  throw "실행 파일을 찾을 수 없습니다: $Target"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = $Target
$shortcut.WorkingDirectory = $ScriptDir
$shortcut.Description = "RisuAI 폰용 ChatGPT/Codex 연결 시작"
$shortcut.Save()

Write-Host "바탕화면 바로가기를 만들었습니다:" -ForegroundColor Green
Write-Host $ShortcutPath
