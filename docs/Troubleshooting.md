# Troubleshooting

## 1) Cable not recognized in Device Manager
- Confirm Windows Update driver install succeeded (internet connected), or install FTDI CDM drivers.
- Use scripts\Collect-Diagnostics.ps1 to capture relevant device and driver state.

## 2) Techstream does not list the interface
- Run scripts\List-PassThru.ps1 and confirm "XHorse - MVCI" exists.
- Ensure bin\mvci32.dll exists and is referenced by FunctionLibrary in the registry.
- Confirm you ran Install-MVCI as Administrator.

## 3) Test-MVCI fails PassThruOpen
- Confirm the FTDI D2XX runtime is installed (part of FTDI CDM drivers).
- Try changing USBDescription in registry Parameters to match the device’s actual USB description.
  (Default "M-VCI"; see MVCI-J2534 docs.)

## 4) Collect full support info
- scripts\Collect-Diagnostics.ps1
Attach the output folder.

