# Techstream setup (J2534 VIM selection)

1) Install this repo’s PassThru entry:
   - run scripts\Install-MVCI.cmd
2) Open Techstream.
3) Go to Setup -> VIM Select.
4) Select "XHorse - MVCI".
5) Connect the cable to the vehicle OBD-II and ignition ON.
6) Connect to vehicle and perform a basic validation (read VIN, health check, DTC scan).

Notes
- J2534 applications discover installed interfaces via registry entries under
  HKLM\Software\PassThruSupport.04.04\... including FunctionLibrary and supported protocol flags.
- This repo registers both 32-bit and 64-bit views for compatibility; Techstream is commonly 32-bit.

