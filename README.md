# MVCI J2534 (Mini-VCI / “XHorse”-style) Windows 10/11 Installer + Support Toolkit

This repo provides an auditable way to:
1) ensure FTDI USB drivers are installed (VCP + D2XX) on Windows 10/11, and
2) register a J2534 PassThru interface so J2534 applications (e.g., Techstream) can discover it.

It uses:
- Official FTDI CDM driver distribution for Windows 10/11 (signed; VCP + D2XX) (FTDI docs / driver portal).
- The open-source `MVCI-J2534` library (MIT license) as the PassThru DLL implementation.

References:
- FTDI driver portal notes Windows Update support and provides Win10/11 installer containing both VCP and D2XX.
- FTDI AN_396 explains CDM install methods for Win10/11 and the combined driver model.
- J2534 device discovery uses `HKLM\Software\PassThruSupport.04.04\...` and values like `FunctionLibrary`.
- MVCI-J2534 documents its registry key and Parameters including `UseD2XX` and `USBDescription`.

## What this repo does NOT include
- Toyota Techstream binaries.
- Any immobilizer/security bypass procedures.
- Any cracked or repackaged drivers.

## Quick start (most common)
Prereqs:
- Windows 10/11 x64
- Administrator PowerShell
- An MVCI/Mini-VCI J2534 cable that enumerates as an FTDI device

Steps:
1. Build or obtain `bin\mvci32.dll` (see "Building mvci32.dll")
2. Run installer:
   - scripts\Install-MVCI.cmd
3. Validate basic J2534 load:
   - scripts\Test-MVCI.ps1
4. In Techstream: Setup -> VIM Select -> choose "XHorse - MVCI" (see docs/Techstream-Setup.md)

## Building mvci32.dll
Option A (recommended): GitHub Actions artifact
- This repo includes a CI workflow that builds `mvci32.dll` using MSYS2/MinGW32.
- Download the artifact from Actions and place it in `bin\mvci32.dll` for releases.

Option B: Local build (Windows)
- Install MSYS2 and the 32-bit MinGW toolchain.
- Add the MVCI-J2534 upstream as a submodule and build it (see third_party/README.md).

## FTDI drivers
FTDI drivers can be installed automatically via Windows Update (internet connected).
If not, install via FTDI’s official CDM installer or use the script’s INF-install path.
From FTDI’s own guidance, the user should accept the FTDI driver license terms.

## Support bundle
If you run into trouble, run:
- scripts\Collect-Diagnostics.ps1
and attach the output folder contents to your support ticket.

## Uninstall
- scripts\Uninstall-MVCI.ps1
(Does not remove FTDI drivers; those are shared system components.)

## Using this repo (end-to-end guide)

### 1) Create the repo + add submodule

From an empty directory:

```bash
git init mvci-j2534-win-installer
cd mvci-j2534-win-installer

# add files from this repo, then:
git submodule add https://github.com/falcon35180/MVCI-J2534 third_party/MVCI-J2534
git add .
git commit -m "Initial MVCI J2534 installer toolkit"
```

The upstream MVCI-J2534 docs state it implements J2534 for XHorse MINI-VCI (and clones) and that its
J2534 identification lives under `HKLM\\Software\\PassThruSupport.04.04\\XHorse - MVCI` with
`Parameters` like `UseD2XX` and `USBDescription`.

### 2) Build mvci32.dll

**Option A (recommended): CI artifact**

- Push to GitHub, let Actions build.
- Download artifact `mvci32.dll`.
- Place it at `bin\\mvci32.dll`.

**Option B: Local build**

- Install MSYS2 + MinGW32 toolchain.
- Then:

```bash
cd third_party/MVCI-J2534
make
cp mvci32.dll ../../bin/mvci32.dll
```

### 3) Install on a Windows 10/11 PC

Open PowerShell as Administrator in the repo root.

If the PC already gets FTDI drivers via Windows Update (common):

```powershell
./scripts/Install-MVCI.ps1
```

If you want the script to attempt FTDI driver install (requires explicit acceptance):

```powershell
./scripts/Install-MVCI.ps1 -InstallFtdiDrivers -AcceptFtdiLicense
```

That will download FTDI’s official package and install INFs via `pnputil`. If FTDI changes the
filename, update `$FtdiPackageUrl` in `scripts/Install-MVCI.ps1`.

### 4) Validate the J2534 DLL loads

```powershell
./scripts/Test-MVCI.ps1
./scripts/List-PassThru.ps1
```

### 5) Configure Techstream

Follow `docs/Techstream-Setup.md`. J2534 applications discover interfaces by enumerating
`PassThruSupport.04.04` entries and reading `FunctionLibrary`, supported protocol flags, etc.

### 6) Support bundle

If something fails:

```powershell
./scripts/Collect-Diagnostics.ps1
```

### 7) Uninstall

```powershell
./scripts/Uninstall-MVCI.ps1
```

## Design rationale (why this works)

- **FTDI drivers:** FTDI explicitly provides Windows 10/11 drivers (VCP + D2XX) and documents
  installation paths; Windows Update may also install automatically.
- **J2534 discovery:** J2534 interfaces are located via `PassThruSupport.04.04` registry keys and
  `FunctionLibrary`.
- **MVCI-J2534 behavior:** The DLL’s expected registry key/parameters (`USBDescription`, `UseD2XX`)
  are documented by the `MVCI-J2534` project itself.

