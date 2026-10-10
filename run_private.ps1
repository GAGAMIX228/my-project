# Closed test: predictions for all 4 tasks with one command (Windows PowerShell 5.1+).
# No training needed - weights are in the repository. No internet needed.
#
#   1) Put the test files into the private\ folder:
#        private\A.npz          (task A)
#        private\B.csv          (task B)
#        private\C\*.wav        (task C - folder with audio files)
#        private\D.csv          (task D)
#      or pass your own paths: .\run_private.ps1 -A file.npz -B file.csv -C folder -D file.csv
#   2) Run from the project folder:
#        powershell -ExecutionPolicy Bypass -File .\run_private.ps1
#   3) Results: out\A, out\B, out\C, out\D (file names submission_seed_{SEED}.*).
#   Self-check on public tests: put public tests into public\ and run
#        powershell -ExecutionPolicy Bypass -File .\run_private.ps1 -A public\A.npz -B public\B.csv -C public\C -D public\D.csv
#        python check_public.py
param(
    [string]$A = "private\A.npz",
    [string]$B = "private\B.csv",
    [string]$C = "private\C",
    [string]$D = "private\D.csv"
)
$ErrorActionPreference = "Continue"   # python writes warnings to stderr - do not treat them as errors
Set-Location $PSScriptRoot
$env:HF_HUB_OFFLINE = "1"          # never go to the internet
$env:PYTHONIOENCODING = "utf-8"    # python prints Russian text

$failed = @()
function Run($name, $path, $cmd) {
    if (-not (Test-Path $path)) { Write-Host "[$name] skipped: not found $path" -ForegroundColor Yellow; return }
    Write-Host "[$name] $cmd" -ForegroundColor Cyan
    $global:LASTEXITCODE = 0
    try { Invoke-Expression $cmd } catch { Write-Host $_ -ForegroundColor Red; $global:LASTEXITCODE = 1 }
    if ($LASTEXITCODE -ne 0) { Write-Host "[$name] FAILED (exit code $LASTEXITCODE)" -ForegroundColor Red; $script:failed += $name }
}

Run "A" $A "python predict.py --test `"$A`" --out-dir out\A"
Run "B" $B "python task_b\predict.py --test `"$B`" --out-dir out\B"
Run "D" $D "python task_d\predict.py --test `"$D`" --out-dir out\D"
Run "C" $C "python task_c\predict.py --test-dir `"$C`" --out-dir out\C"   # slowest: features from audio

if ($failed.Count -gt 0) { Write-Host "`nFAILED: $($failed -join ', ') - send the red output above to Claude" -ForegroundColor Red }
Write-Host "`nDone. Files:" -ForegroundColor Green
if (Test-Path out) { Get-ChildItem out -Recurse -File | ForEach-Object { "{0,-60} {1,12:N0} bytes" -f $_.FullName, $_.Length } }
