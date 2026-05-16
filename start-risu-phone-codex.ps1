$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$UrlFile = Join-Path $ScriptDir "latest-risu-phone-url.txt"
$CloudflaredLog = Join-Path $ScriptDir "cloudflared-phone.log"
$ClawgateLog = Join-Path $ScriptDir "clawgate-phone.log"
$Port = 8082

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Require-Command {
  param(
    [string]$Name,
    [string]$InstallHint
  )

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name 명령을 찾을 수 없습니다. $InstallHint"
  }
}

function Test-Clawgate {
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port" -TimeoutSec 2
    return $response.StatusCode -eq 200
  } catch {
    return $false
  }
}

function Wait-Clawgate {
  $deadline = (Get-Date).AddSeconds(25)
  while ((Get-Date) -lt $deadline) {
    if (Test-Clawgate) {
      return
    }
    Start-Sleep -Milliseconds 700
  }
  throw "clawgate가 http://127.0.0.1:$Port 에서 응답하지 않습니다. clawgate 창의 오류를 확인하세요."
}

function Wait-TunnelUrl {
  $deadline = (Get-Date).AddSeconds(45)
  $pattern = "https://[a-z0-9-]+\.trycloudflare\.com"

  while ((Get-Date) -lt $deadline) {
    if (Test-Path $CloudflaredLog) {
      $content = Get-Content -Raw -LiteralPath $CloudflaredLog -ErrorAction SilentlyContinue
      $match = [regex]::Match($content, $pattern)
      if ($match.Success) {
        return $match.Value
      }
    }
    Start-Sleep -Milliseconds 700
  }

  throw "cloudflared 로그에서 trycloudflare 주소를 찾지 못했습니다. cloudflared 창의 오류를 확인하세요."
}

Write-Host "RisuAI 폰용 ChatGPT/Codex 연결 실행기" -ForegroundColor Green
Write-Host "이 창은 새 터널 주소를 찾아 클립보드와 txt 파일에 저장합니다."

Require-Command "clawgate" "먼저 clawgate를 설치하고 'clawgate login'을 실행하세요."
Require-Command "cloudflared" "PowerShell에서 'winget install -e --id Cloudflare.cloudflared'를 실행하세요."

Write-Step "기존 로그 정리"
Remove-Item -LiteralPath $CloudflaredLog -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ClawgateLog -Force -ErrorAction SilentlyContinue

Write-Step "clawgate 실행"
if (Test-Clawgate) {
  Write-Host "이미 http://127.0.0.1:$Port 에서 clawgate가 실행 중입니다."
} else {
  $clawgateCommand = "clawgate --host=0.0.0.0 --port=$Port 2>&1 | Tee-Object -FilePath `"$ClawgateLog`""
  Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $clawgateCommand -WindowStyle Normal
  Wait-Clawgate
}

Write-Step "cloudflared 터널 실행"
$cloudflaredCommand = "cloudflared tunnel --url http://localhost:$Port --protocol http2 2>&1 | Tee-Object -FilePath `"$CloudflaredLog`""
Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $cloudflaredCommand -WindowStyle Normal

Write-Step "새 HTTPS 주소 찾는 중"
$url = Wait-TunnelUrl

Set-Content -LiteralPath $UrlFile -Value $url -Encoding UTF8
try {
  Set-Clipboard -Value $url
  $clipboardMessage = "클립보드에 복사했습니다."
} catch {
  $clipboardMessage = "클립보드 복사는 실패했지만 txt 파일에는 저장했습니다."
}

Write-Host ""
Write-Host "완료!" -ForegroundColor Green
Write-Host "폰 RisuAI의 URL에 아래 주소를 넣으세요:" -ForegroundColor Yellow
Write-Host $url -ForegroundColor Cyan
Write-Host ""
Write-Host $clipboardMessage
Write-Host "저장 위치: $UrlFile"
Write-Host ""
Write-Host "주의: clawgate 창과 cloudflared 창을 닫으면 연결이 끊깁니다."
Write-Host "Risu 테스트 전 폰 Safari/Chrome에서 주소를 먼저 열어 status ok가 뜨는지 확인하세요."
Write-Host ""
Read-Host "Enter를 누르면 이 안내 창만 닫습니다"
