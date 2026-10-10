# Закрытый тест: предсказания по всем 4 задачам одной командой (Windows PowerShell).
# Обучение не нужно — веса лежат в репозитории.
#
#   1) Положите закрытые тесты в папку private\ :
#        private\A.npz          (задача A)
#        private\B.csv          (задача B)
#        private\C\*.wav        (задача C — папка с аудиофайлами)
#        private\D.csv          (задача D)
#      или укажите свои пути: .\run_private.ps1 -A путь.npz -B путь.csv -C папка -D путь.csv
#   2) Запуск из папки проекта:
#        powershell -ExecutionPolicy Bypass -File .\run_private.ps1
#   3) Готовые файлы — в out\A, out\B, out\C, out\D (имена submission_seed_{SEED}.*).
param(
    [string]$A = "private\A.npz",
    [string]$B = "private\B.csv",
    [string]$C = "private\C",
    [string]$D = "private\D.csv"
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Run($name, $path, $cmd) {
    if (-not (Test-Path $path)) { Write-Host "[$name] пропуск: не найден $path" -ForegroundColor Yellow; return }
    Write-Host "[$name] $cmd" -ForegroundColor Cyan
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) { throw "[$name] ошибка, код $LASTEXITCODE" }
}

Run "A" $A "python predict.py --test `"$A`" --out-dir out\A"
Run "B" $B "python task_b\predict.py --test `"$B`" --out-dir out\B"
Run "D" $D "python task_d\predict.py --test `"$D`" --out-dir out\D"
Run "C" $C "python task_c\predict.py --test-dir `"$C`" --out-dir out\C"   # самая долгая (признаки из аудио)

Write-Host "`nГотово. Файлы:" -ForegroundColor Green
Get-ChildItem out -Recurse -File | ForEach-Object { "{0,-60} {1,10:N0} байт" -f $_.FullName, $_.Length }
