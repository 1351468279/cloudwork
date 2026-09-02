# CloudWork Windows One-Line Installer
$ErrorActionPreference = 'Stop'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   ⚡ Installing CloudWork AI Agent Commander for Windows" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

$InstallDir = "$HOME\.cloudwork\bin"
if (!(Test-Path -Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$BinaryPath = "$InstallDir\cloudwork.exe"

# 检查当前项目内是否有现成编译好的二进制，若有则优先安装
$LocalBin = ".\daemon\bin\cloudwork-daemon.exe"
if (Test-Path -Path $LocalBin) {
    Copy-Item -Path $LocalBin -Destination $BinaryPath -Force
    Write-Host "✓ Copied local build to $BinaryPath" -ForegroundColor Green
} else {
    Write-Host "Downloading latest release from GitHub..." -ForegroundColor Yellow
    $DownloadUrl = "https://github.com/cloudwork/cloudwork/releases/latest/download/cloudwork-daemon-windows-amd64.exe"
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryPath -UseBasicParsing
        Write-Host "✓ Download complete!" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Failed to download prebuilt binary. You can build it locally with 'go build ./cmd/cloudwork-daemon'" -ForegroundColor Red
    }
}

# 将安装路径加入用户 PATH 环境变量
$UserPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
if ($UserPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", [EnvironmentVariableTarget]::User)
    $env:Path += ";$InstallDir"
    Write-Host "✓ Added $InstallDir to PATH" -ForegroundColor Green
}

Write-Host "`n🎉 Installation Succeeded!" -ForegroundColor Green
Write-Host "You can now run 'cloudwork' from any terminal to start the agent commander." -ForegroundColor Cyan
