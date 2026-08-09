# Adding an OCR Language to Windows (for ShareX)

Runbook for making a language appear in **ShareX's OCR language dropdown**.

ShareX doesn't ship its own OCR engine — it calls the built-in **`Windows.Media.Ocr`** API and
lists whatever recognizers Windows has installed. So this is entirely a Windows problem:
install the recognizer in the OS, and ShareX picks it up. No Python, no Tesseract, no venv.

Verified working on **Windows 11 Pro 25H2, build 10.0.26200.8875**, 2026-08-08 (Spanish / es-ES).

---

## The one thing that matters

> **`Language.OCR` has a hard dependency on `Language.Basic` for the same locale.**
> Install the OCR package first and CBS does **not** return a clean error — it **hangs at
> `Internal_Finalize`** and the operation silently never completes.

Straight from the package manifest (`.mum` inside the cab):

```xml
<declareCapability>
  <capability>  <capabilityIdentity name="Language.OCR"   version="1.0" language="es-es" /></capability>
  <dependency>  <capabilityIdentity name="Language.Basic" version="1.0" language="es-es" /></dependency>
</declareCapability>
```

**Always install `Language.Basic` before `Language.OCR`.**

---

## Procedure

Replace `es-ES` with your target locale throughout.

### 1. Check what's already installed

No admin needed:

```powershell
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation.UniversalApiContract, ContentType=WindowsRuntime]
[Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | Select-Object LanguageTag, DisplayName
```

`C:\Windows\OCR` is the same information as folders — one per installed recognizer.

### 2. Confirm nothing blocks Windows Update

Most "I can't install languages" cases are a policy block, not a missing file. Check before
downloading anything by hand:

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing' `
    | Select-Object RepairContentServerSource, UseWindowsUpdate, LocalSourcePath
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' `
    | Select-Object WUServer, DoNotConnectToWindowsUpdateInternetLocations
```

Empty / missing keys = unrestricted. A `WUServer` (WSUS) value is the classic cause of
FoD failures — such machines need *"Download repair content and optional features directly
from Windows Update"* enabled.

### 3. Install — online route (preferred)

Elevated. Order matters:

```powershell
Add-WindowsCapability -Online -Name 'Language.Basic~~~es-ES~0.0.1.0'
Add-WindowsCapability -Online -Name 'Language.OCR~~~es-ES~0.0.1.0'
```

`Install-Language es-ES` also works and resolves dependencies automatically, but it drags in
Speech, TextToSpeech and Handwriting too. The two commands above are the minimal footprint.

Neither changes your display language.

### 4. Install — offline route (`.cab` files)

For machines that genuinely can't reach Windows Update. You need **both** cabs — the OCR cab
alone cannot install:

| File | Role |
|---|---|
| `Microsoft-Windows-LanguageFeatures-Basic-es-es-Package-amd64.cab` | Prerequisite — install **first** |
| `Microsoft-Windows-LanguageFeatures-OCR-es-es-Package-amd64.cab` | The recognizer |

Source: **"Windows 11, version 24H2 Features on Demand, Disk 1"** ISO (Visual Studio
Subscriptions / VLSC), or UUP dump. Architecture and build must match the OS —
`amd64`, build `26100` for 24H2/25H2. (25H2 is an enablement package over the 26100
servicing base, so 26100-versioned packages are correct there.)

```powershell
Add-WindowsPackage -Online -NoRestart -PackagePath 'C:\path\Microsoft-Windows-LanguageFeatures-Basic-es-es-Package-amd64.cab'
Add-WindowsPackage -Online -NoRestart -PackagePath 'C:\path\Microsoft-Windows-LanguageFeatures-OCR-es-es-Package-amd64.cab'
```

Mixing routes is fine — pulling `Language.Basic` from Windows Update and then installing a
hand-downloaded OCR cab works, and is exactly what succeeded here.

### 5. Verify at the OS level

Re-run the Step 1 command. You want the new tag listed **and** a matching folder under
`C:\Windows\OCR`. If it's absent, stop — ShareX cannot show what Windows doesn't have.

### 6. Restart ShareX properly

**ShareX enumerates OCR languages once, at startup.** Closing the window only minimises it
to the tray, so a running instance shows the old list indefinitely.

1. Tray icon (may be under the `^` overflow arrow) → **right-click → Exit**
2. Verify: `Get-Process ShareX -ErrorAction SilentlyContinue` returns nothing
3. Relaunch → **Tools → OCR** → pick the language from the dropdown (it persists)

Test on text with diacritics (`ñ`, `á`, `é`) — correct accents prove the new recognizer is
active rather than English silently handling it.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| DISM/`Add-WindowsPackage` hangs, log stops at `Internal_Finalize`, `TiWorker` alive but idle | `Language.Basic` missing for that locale | Install `Language.Basic` first |
| `0x800f0954` | FoD source unreachable | Use the offline cab route (§4) |
| `0x800f081e` | Package build ≠ OS servicing base | Get cabs matching the build (26100 for 24H2/25H2) |
| Exit code `0xC000013A` from DISM | Console window closed mid-run | Run via a script writing to a log, not an interactive window |
| Language installed, still absent in ShareX | ShareX never restarted | Tray → **Exit**, then relaunch (§6) |

**Reading the real error.** The DISM log often stops dead with no explanation. `C:\Windows\Logs\CBS\CBS.log`
(admin-only, usually locked — copy it first) has the actual failure.

**Inspecting a cab before installing** — no admin, no install, reveals the dependencies:

```powershell
expand.exe -D  .\Some-Package.cab                        # list contents
expand.exe -F:*.mum .\Some-Package.cab C:\temp\out       # extract manifests
Select-String C:\temp\out\*.mum -Pattern 'capabilityIdentity'
```

**A hung servicing session blocks everything after it.** Windows permits one CBS transaction at
a time. Check with `Get-Process TiWorker, TrustedInstaller`. It often clears itself within
~30 min; a reboot is the reliable fix.

---

## Rollback

```powershell
Remove-WindowsCapability -Online -Name 'Language.OCR~~~es-ES~0.0.1.0'
Remove-WindowsCapability -Online -Name 'Language.Basic~~~es-ES~0.0.1.0'
```

---

## Scripts in this folder

| Script | Use |
|---|---|
| `finish-spanish-ocr.ps1` | Online route — `Language.Basic` from Windows Update, then the local OCR cab. **This is the one that worked.** |
| `install-spanish-ocr.ps1` | Fully offline route — both cabs from disk, correct order, refuses to start if either is missing |

Both need an elevated shell:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\admin\Documents\OCR\finish-spanish-ocr.ps1"
```

### Reusing these for another language

Edit the locale strings — e.g. `es-ES` → `fr-FR`, and `-es-es-` → `-fr-fr-` in cab filenames.
`es-MX` is set up but commented out in `install-spanish-ocr.ps1`; note it needs its **own**
`Language.Basic~es-MX`, since Basic and OCR are per-locale, not per-language.
