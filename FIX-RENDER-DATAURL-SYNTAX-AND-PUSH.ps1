param(
  [string]$RepoRoot = ".",
  [string]$BackendDir = "backend"
)

Write-Host "=== FIX: Render dataUrl syntax crash + push branch ===" -ForegroundColor Cyan

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Resolve-Path $RepoRoot -ErrorAction Stop).Path
Set-Location $root

$backendPath = Join-Path $root $BackendDir
if (-not (Test-Path $backendPath)) { Write-Error "Missing backend folder: $backendPath"; exit 1 }

$indexJs = Join-Path $backendPath "index.js"
if (-not (Test-Path $indexJs)) { Write-Error "Missing backend/index.js"; exit 1 }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$bakDir = Join-Path $root ("backup_backend_renderfix_" + $ts)
New-Item -ItemType Directory -Force -Path $bakDir | Out-Null
Copy-Item $indexJs (Join-Path $bakDir "index.js.bak") -Force
Write-Host "Backup: $bakDir\index.js.bak" -ForegroundColor DarkGray

# IMPORTANT: single-quoted here-string so PowerShell DOES NOT expand ${...}
$code = @'
"use strict";

const express = require("express");
const cors = require("cors");
const multer = require(
