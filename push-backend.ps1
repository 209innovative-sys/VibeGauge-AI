Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " VibeGauge / Confusion-AI Git Push Script"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verify this is a git repo
if (-not (Test-Path ".git")) {
    Write-Host "ERROR: This folder is not a git repository." -ForegroundColor Red
    Write-Host "Open PowerShell in the correct project folder and try again."
    exit 1
}

# 2. Show git status
Write-Host "Checking git status..." -ForegroundColor Yellow
git status
Write-Host ""

# 3. Ask user confirmation
$confirm = Read-Host "Do you want to add, commit, and push these changes? (y/n)"
if ($confirm -ne "y") {
    Write-Host "Aborted. No changes were pushed." -ForegroundColor Red
    exit 0
}

# 4. Add all changes
Write-Host ""
Write-Host "Adding files..." -ForegroundColor Yellow
git add .

# 5. Commit
$commitMessage = Read-Host "Enter commit message (or press Enter for default)"
if ([string]::IsNullOrWhiteSpace($commitMessage)) {
    $commitMessage = "Fix CORS and backend deployment issues"
}

Write-Host "Committing changes..." -ForegroundColor Yellow
git commit -m "$commitMessage"

# 6. Detect branch
$branch = git branch --show-current
Write-Host "Current branch: $branch" -ForegroundColor Cyan

# 7. Push
Write-Host ""
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push origin $branch

# 8. Done
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " PUSH COMPLETE"
Write-Host " GitHub updated → Render will auto-deploy"
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
