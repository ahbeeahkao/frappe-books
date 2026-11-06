# Copyright (c) 2026, Frappe Technologies Pvt. Ltd. and contributors
# For license information, please see license.txt
#
# Install Frappe Books on a Windows laptop, in one command.
#
#   .\install-books.ps1                 # Ubuntu in WSL2, Books on http://localhost:8000/books
#   .\install-books.ps1 -Port 8080
#
# The script turns on WSL2, installs Ubuntu, creates the Linux user "books",
# copies install-books.sh into it, runs it, opens the port to your network and
# registers a task that starts Books when you sign in. Run it in an
# Administrator PowerShell; a restart may be needed the first time.

#Requires -RunAsAdministrator
[CmdletBinding()]
param(
  [string]$Site = 'books.localhost',
  [int]$Port = 8000,
  [string]$AdminPassword = '',
  [string]$DbPassword = '',
  [string]$Distro = '',
  [string]$BenchDir = '',
  [switch]$NoAutostart,
  [switch]$SkipMirroredNetworking
)

$ErrorActionPreference = 'Stop'
$Script:Installer = Join-Path $PSScriptRoot 'install-books.sh'
$LinuxUser = 'books'

function Say($message) { Write-Host "`n==> $message" -ForegroundColor Cyan }
function Note($message) { Write-Host "    $message" }
function Warn($message) { Write-Host "warning: $message" -ForegroundColor Yellow }
function Fail($message) { Write-Host "error: $message" -ForegroundColor Red; exit 1 }

# WSL prints UTF-16 unless asked otherwise, which mangles names in PowerShell,
# and PowerShell 5.1 pipes text as ASCII unless told to use UTF-8.
$env:WSL_UTF8 = '1'
$OutputEncoding = [Text.UTF8Encoding]::new($false)

# Write a file inside WSL by piping through tee: every argument stays a single
# word, so nothing depends on how PowerShell quotes a command line, and a long
# script never has to fit on one.
function Write-WslFile {
  param(
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
    [Parameter(Mandatory)][string]$Path,
    [string]$As = 'root'
  )
  ($Content -replace "`r`n", "`n") | wsl.exe -d $script:DistroName -u $As -- tee $Path | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail "could not write $Path inside WSL" }
}

function Invoke-WslBash {
  param(
    [Parameter(Mandatory)][string]$Script,
    [string]$As = 'root'
  )
  Write-WslFile -Content $Script -Path /tmp/wsl-books.sh -As $As
  wsl.exe -d $script:DistroName -u $As -- bash /tmp/wsl-books.sh
  if ($LASTEXITCODE -ne 0) { Fail "a step inside WSL failed (exit $LASTEXITCODE)" }
}

# ------------------------------------------------------------------ preflight

if (-not (Test-Path $Script:Installer)) {
  Fail "install-books.sh is missing; keep install-books.ps1 and install-books.sh in the same folder"
}
if ($Port -lt 1 -or $Port -gt 65535) { Fail "-Port must be between 1 and 65535" }
if ($Port -lt 1024) { Warn "ports below 1024 usually need extra Windows permissions; 8000 is a good default" }

$build = [Environment]::OSVersion.Version.Build
if ($build -lt 19041) { Fail "WSL2 needs Windows 10 version 2004 (build 19041) or newer; this is build $build" }

Say "Checking WSL2"
wsl.exe --status *> $null
if ($LASTEXITCODE -ne 0) {
  Note "WSL is not enabled yet: turning it on now"
  dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
  dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
  Write-Host ''
  Write-Host 'Restart Windows, then run this script again.' -ForegroundColor Yellow
  exit 1
}
wsl.exe --update *> $null
wsl.exe --set-default-version 2 *> $null

# ------------------------------------------------------------------- distro

Say "Preparing Ubuntu"
if (-not $Distro) {
  $online = (wsl.exe --list --online) -join "`n"
  foreach ($candidate in @('Ubuntu-26.04', 'Ubuntu-24.04', 'Ubuntu')) {
    if ($online -match [regex]::Escape($candidate)) { $Distro = $candidate; break }
  }
  if (-not $Distro) { Fail "no Ubuntu distribution is available from the Microsoft Store; pass -Distro" }
}

$installed = ((wsl.exe --list --quiet) -join "`n") -split "`n" | ForEach-Object { $_.Trim() }
if ($installed -contains $Distro) {
  Note "$Distro is already installed"
} else {
  Note "installing $Distro (this downloads a few hundred MB)"
  wsl.exe --install -d $Distro --no-launch
  if ($LASTEXITCODE -ne 0) { Fail "could not install $Distro (exit $LASTEXITCODE)" }
}
$script:DistroName = $Distro

# First launch as root: no user prompt, then a known sudo-capable user.
Note "creating the Linux user '$LinuxUser'"
$linuxPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
Invoke-WslBash -As root -Script @"
set -eu
id -u $LinuxUser >/dev/null 2>&1 || useradd -m -s /bin/bash $LinuxUser
echo '$LinuxUser:$linuxPassword' | chpasswd
printf '%s\n' '$LinuxUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$LinuxUser
chmod 0440 /etc/sudoers.d/$LinuxUser
grep -q 'systemd=true' /etc/wsl.conf 2>/dev/null || printf '[boot]\nsystemd=true\n[user]\ndefault=$LinuxUser\n' > /etc/wsl.conf
"@

# ------------------------------------------------------- mirrored networking

# Mirrored mode lets the rest of the house reach this port; NAT mode hides it
# behind the WSL virtual switch unless every port is proxied by hand.
if (-not $SkipMirroredNetworking -and $build -ge 22621) {
  Say "Opening the port to your network (mirrored networking)"
  $wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
  $mode = "[wsl2]`nnetworkingMode=mirrored`n"
  if (-not (Test-Path $wslConfig)) {
    Set-Content -Path $wslConfig -Value $mode -Encoding ASCII
    Note "wrote $wslConfig"
  } elseif ((Get-Content -Raw $wslConfig) -match 'networkingMode') {
    Note "$wslConfig already sets networkingMode"
  } elseif ((Get-Content -Raw $wslConfig) -notmatch '\[wsl2\]') {
    Add-Content -Path $wslConfig -Value "`n$mode"
    Note "appended [wsl2] networkingMode=mirrored to $wslConfig"
  } else {
    Warn "$wslConfig has a [wsl2] section without networkingMode; add 'networkingMode=mirrored' by hand for LAN access"
  }
  wsl.exe --shutdown *> $null
} else {
  Warn "skipping mirrored networking: only this PC can reach Books at localhost"
}

# ---------------------------------------------------------------- the install

Say "Installing Frappe Books inside $Distro (10 to 30 minutes)"
foreach ($value in @($AdminPassword, $DbPassword, $BenchDir)) {
  if ($value -match "'") { Fail "passwords and paths cannot contain a single quote" }
}

wsl.exe -d $Distro -u root -- mkdir -p /opt/books
if ($LASTEXITCODE -ne 0) { Fail "could not create /opt/books inside WSL" }
Write-WslFile -Content (Get-Content -Raw $Script:Installer) -Path /opt/books/install-books.sh
wsl.exe -d $Distro -u root -- chmod +x /opt/books/install-books.sh
if ($LASTEXITCODE -ne 0) { Fail "could not make the installer executable" }

# The arguments go in a file too, so PowerShell never re-quotes them.
$command = "exec /opt/books/install-books.sh --site '$Site' --port '$Port'"
if ($AdminPassword) { $command += " --admin-password '$AdminPassword'" }
if ($DbPassword) { $command += " --db-password '$DbPassword'" }
if ($BenchDir) { $command += " --bench-dir '$BenchDir'" }
Write-WslFile -Content "set -eu`n$command`n" -Path /tmp/run-books.sh

wsl.exe -d $Distro -u $LinuxUser -- bash /tmp/run-books.sh
if ($LASTEXITCODE -ne 0) { Fail "the installer failed (exit $LASTEXITCODE); scroll up for the failing step" }

# ------------------------------------------------------------------- the rest

Say "Letting Windows through the firewall"
if (-not (Get-NetFirewallRule -DisplayName "Frappe Books ($Port)" -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName "Frappe Books ($Port)" -Direction Inbound -Action Allow `
    -Protocol TCP -LocalPort $Port -Profile Private | Out-Null
}

if (-not $NoAutostart) {
  Say "Starting Books when you sign in"
  $action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wsl.exe" `
    -Argument "-d `"$Distro`" -u $LinuxUser --exec /bin/true"
  $trigger = New-ScheduledTaskTrigger -AtLogOn
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
  Register-ScheduledTask -TaskName 'Frappe Books' -Action $action -Trigger $trigger `
    -Settings $settings -RunLevel Highest -Force | Out-Null
  Note "task 'Frappe Books' registered"
}

$lanIp = (Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
  Select-Object -First 1).IPAddress

Write-Host ''
Write-Host 'Frappe Books is installed' -ForegroundColor Green
Write-Host ''
Write-Host "  This laptop : http://localhost:$Port/books"
if ($lanIp) { Write-Host "  Your network: http://${lanIp}:$Port/books" }
Write-Host "  Site        : $Site"
Write-Host ''
Write-Host 'Passwords are on the last lines of the installer output and in:'
Write-Host "  \\wsl.localhost\$Distro\home\$LinuxUser\.frappe-books-install"
Write-Host ''
Write-Host 'Keep it running:' -ForegroundColor Cyan
Write-Host '  - set Windows to never sleep while plugged in, or Books stops with the laptop'
Write-Host '  - set Active Hours so Windows Update does not reboot at night'
Write-Host '  - `wsl --shutdown` stops it; rerun the scheduled task or reboot to start it'
Write-Host ''
