# Installs Spanish OCR support for the Windows.Media.Ocr engine (used by ShareX).
#
# ORDER MATTERS: Language.OCR declares a hard dependency on Language.Basic for the
# same locale. Installing the OCR cab first is what caused CBS to hang at finalize.
#
# Run ELEVATED, and only after a reboot has cleared any stuck servicing session.

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'
$dir = 'C:\Users\admin\Documents\OCR'

# Basic must precede OCR for each locale. Drop the es-mx pair to install es-ES only.
$order = @(
    'Microsoft-Windows-LanguageFeatures-Basic-es-es-Package-amd64.cab',
    'Microsoft-Windows-LanguageFeatures-OCR-es-es-Package-amd64.cab'
    # 'Microsoft-Windows-LanguageFeatures-Basic-es-mx-Package-amd64.cab',
    # 'Microsoft-Windows-LanguageFeatures-OCR-es-mx-Package-amd64.cab'
)

# Fail loudly up front rather than part-way through a servicing transaction.
$missing = $order | Where-Object { -not (Test-Path (Join-Path $dir $_)) }
if ($missing) {
    Write-Host "Missing required cab(s):" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "`nDownload from the Windows 11 24H2 'Features on Demand, Disk 1' ISO (build 26100, amd64)."
    return
}

foreach ($cab in $order) {
    $path = Join-Path $dir $cab
    Write-Host "`nInstalling $cab ..." -ForegroundColor Cyan
    $r = Add-WindowsPackage -Online -PackagePath $path -NoRestart
    Write-Host "  done (RestartNeeded=$($r.RestartNeeded))" -ForegroundColor Green
}

Write-Host "`n=== OCR recognizers now available ===" -ForegroundColor Cyan
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation.UniversalApiContract, ContentType=WindowsRuntime]
[Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages |
    Select-Object LanguageTag, DisplayName | Format-Table -AutoSize

Write-Host "=== C:\Windows\OCR ===" -ForegroundColor Cyan
Get-ChildItem 'C:\Windows\OCR' -Directory | Select-Object Name

Write-Host "`nIf Spanish appears above, fully exit ShareX (tray icon -> Exit) and reopen it." -ForegroundColor Yellow
