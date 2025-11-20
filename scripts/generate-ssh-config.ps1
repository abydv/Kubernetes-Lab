param()

$projectDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Push-Location $projectDir

# Extract vagrant ssh-config
try {
  $outFile = Join-Path $projectDir '.vagrant_ssh_config'
  & vagrant ssh-config > $outFile
} catch {
  Write-Error "Failed to run 'vagrant ssh-config'. Ensure Vagrant is installed."
  Pop-Location
  exit 1
}

$userSshDir = Join-Path $env:USERPROFILE '.ssh'
if (-not (Test-Path $userSshDir)) {
  New-Item -ItemType Directory -Path $userSshDir | Out-Null
}

$userConfig = Join-Path $userSshDir 'config'

# Load vagrant ssh-config content
$vagrantConfig = Get-Content $outFile -Raw

# Extract VM names
$vmNames = ([regex]::Matches($vagrantConfig, 'Host\s+([^\s]+)')) |
           ForEach-Object { $_.Groups[1].Value } |
           Select-Object -Unique

# Read or initialize config
if (Test-Path $userConfig) {
  $existing = Get-Content $userConfig -Raw
} else {
  $existing = ""
}

$new = $existing

# Remove ALL previous blocks for these VM names
foreach ($vm in $vmNames) {
  Write-Host "Checking for duplicate Host: $vm"

  # Remove Host vm ... until next Host or end-of-file
  $pattern = "(?ms)^Host\s+$vm\b.*?(?=^Host\s+|\z)"

  while ($new -match $pattern) {
    Write-Host " - Removing duplicate block for '$vm'"
    $new = [regex]::Replace($new, $pattern, "")
  }
}

# Clean excess whitespace
$new = $new.Trim()

# Append fresh vagrant ssh-config (clean, no duplicates)
$new += "`n`n" + $vagrantConfig.Trim() + "`n"

# Write atomically
$tmp = "$userConfig.tmp.$((Get-Date).ToString('yyyyMMddHHmmss'))"
$new | Out-File -FilePath $tmp -Encoding ASCII
Move-Item -Path $tmp -Destination $userConfig -Force

Pop-Location

Write-Host "Done. No duplicates. Try: ssh <vm-name>"
