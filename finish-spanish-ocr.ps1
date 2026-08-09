# Completes Spanish OCR setup for the Windows.Media.Ocr engine (used by ShareX).
#
# Step 1 pulls ONLY the missing prerequisite (Language.Basic~es-ES) from Windows Update.
# Step 2 installs the es-es OCR cab already present in this folder.
# Nothing here touches the display language.
#
# Run ELEVATED.

#Requires -RunAsAdministrator

$sp   = 'C:\Users\admin\AppData\Local\Temp\claude\c--Users-admin-Documents-OCR\92229a57-5977-45ae-8c75-98f7f45e5817\scratchpad'
$out  = Join-Path $sp 'finish-result.txt'
$cab  = 'C:\Users\admin\Documents\OCR\Microsoft-Windows-LanguageFeatures-OCR-es-es-Package-amd64.cab'

function Log($m) { $m | Tee-Object -FilePath $out -Append | Out-Null }
"=== started ===" | Out-File $out -Encoding utf8

# --- Step 1: prerequisite from Windows Update -------------------------------
# 0x800f0954 here means the FoD source is unreachable and we fall back to an
# offline Microsoft-Windows-LanguageFeatures-Basic-es-es-Package-amd64.cab.
Log "--- Step 1: Language.Basic~~~es-ES~0.0.1.0 ---"
$basicOk = $false
try {
    $r = Add-WindowsCapability -Online -Name 'Language.Basic~~~es-ES~0.0.1.0' -ErrorAction Stop
    Log "OK  RestartNeeded=$($r.RestartNeeded)"
    $basicOk = $true
} catch {
    Log "FAIL $($_.Exception.Message)"
}

# --- Step 2: OCR pack from the local cab ------------------------------------
# Skipped on prerequisite failure: that is the exact ordering that hung CBS before.
if ($basicOk) {
    Log "--- Step 2: OCR es-es cab ---"
    try {
        $r = Add-WindowsPackage -Online -PackagePath $cab -NoRestart -ErrorAction Stop
        Log "OK  RestartNeeded=$($r.RestartNeeded)"
    } catch {
        Log "FAIL $($_.Exception.Message)"
        # Cab refused, but WU is clearly reachable - try the capability instead.
        Log "--- Step 2b: falling back to Language.OCR capability ---"
        try {
            $r = Add-WindowsCapability -Online -Name 'Language.OCR~~~es-ES~0.0.1.0' -ErrorAction Stop
            Log "OK  RestartNeeded=$($r.RestartNeeded)"
        } catch {
            Log "FAIL $($_.Exception.Message)"
        }
    }
} else {
    Log "SKIPPED Step 2 - prerequisite missing, installing OCR now would hang CBS."
}

# --- Verify -----------------------------------------------------------------
Log "=== OCR recognizers available ==="
try {
    $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation.UniversalApiContract, ContentType=WindowsRuntime]
    [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages |
        ForEach-Object { Log "  $($_.LanguageTag)  $($_.DisplayName)" }
} catch {
    Log "FAIL reading recognizers: $($_.Exception.Message)"
}

Log "=== C:\Windows\OCR ==="
Get-ChildItem 'C:\Windows\OCR' -Directory | ForEach-Object { Log "  $($_.Name)" }
Log "=== done ==="
