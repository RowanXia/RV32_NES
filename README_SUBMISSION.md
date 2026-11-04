# RV32_NES submission package

This directory is self-contained at the project-root level: open
`RV32_NES.pds` from this directory after installing the required PDS device
support.  The PDS source and constraint paths, and the `filelist` entries,
are relative to this directory.

## Contents

- `src/` — FPGA RTL and generated IP source files.
- `pds/` — board timing and physical constraints.
- `filelist/` — RTL file lists for command-line/review use.
- `software/` — CoreMark/NES firmware sources, build scripts, ELF/BIN, and
  RAM initialization files.
- `bitstream/RV32_NES.sbit` — normal FPGA bitstream without an inserted
  DebugCore.
- `debug/RV32_NES_debug.sbit` — FPGA bitstream with an inserted DebugCore.
- `debug/RV32_NES_debug_syn.fic` — ILA probe configuration used only when
  regenerating a debug build.

## SD card image preparation

The NES game image is `games/output.bin`.  Program this file to the SD card
with **Win32 Disk Imager** before powering the board:

1. Insert the target SD card and make sure any important data on it has been
   backed up.  Writing the image overwrites the selected device.
2. Start Win32 Disk Imager and select `games/output.bin` as the image file.
   If the file picker shows only `.img` files, change its file type to
   `All files (*.*)`; do not rename or modify `output.bin`.
3. Select the drive letter assigned to the SD card, verify it carefully, then
   click `Write` and wait for completion.
4. Use Windows "Safely Remove Hardware" before inserting the card into the
   development board.

## Host-PC program (serial report and NES handoff)

After programming the FPGA and connecting the board UART, run the host-PC
program from the package root with relative paths:

```powershell
cd .\software\board_app
py .\rv32_benchmark_then_nes.py --port COM9 --save-report .\board_report
```

Replace `COM9` with the COM port assigned to the board.  The command sends the
report request, saves the received CoreMark/performance report under
`software\board_app\board_report\`, acknowledges the validated report, and
then enters the NES control window.  Press `Esc` to close that window.

The command deliberately does **not** pass `--manifest`: it is independent of
the build ID, clock-frequency label, compiler flags, and other version-specific
metadata.  Use this form for normal demonstration and submission testing.

For a report-only run that does not open the NES keyboard-control window:

```powershell
cd .\software\board_app
py .\rv32_benchmark_then_nes.py --port COM9 --save-report .\board_report --no-gui
```

`--manifest .\production_manifest.json` is optional and should be used only
when a manifest has been prepared for the exact programmed build; it performs
version/build consistency checking and can reject a different valid build.


## DebugCore note

The `.fic` contains a machine-specific absolute path to its synthesized ADF
netlist.  After moving this package, run Synthesize at the new location and
then open/regenerate the Fabric Inserter configuration before inserting the
DebugCore and generating a debug bitstream.

Generated logs, old task backups, historical audit reports and tool lock
files are intentionally excluded.
