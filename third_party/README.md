# third_party/

Recommended: add MVCI-J2534 as a submodule:

git submodule add https://github.com/falcon35180/MVCI-J2534 third_party/MVCI-J2534

Then build mvci32.dll via CI (preferred) or locally with MSYS2/MinGW32.
See .github/workflows/build-mvci32.yml

## FTDI CDM driver package

The official FTDI CDM driver ZIP (e.g. `CDM2123620_Setup.zip`) is included at:

    third_party/ftdi/CDM2123620_Setup.zip

`scripts/Install-MVCI.ps1` will automatically use this bundled ZIP when invoked with
`-InstallFtdiDrivers -AcceptFtdiLicense`, unless the `-FtdiPackageZipPath` parameter is provided.
