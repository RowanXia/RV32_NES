# RV32_NES: RISC-V SoC with CoreMark and NES Demonstration

This repository contains the final FPGA submission project for a configurable RV32 RISC-V SoC integrated with CoreMark performance reporting and an NES demonstration system.  The project is self-contained at the repository root: open `RV32_NES.pds` in Pango Design Suite (PDS) after installing the required device support.

## Final implementation snapshot

| Item | Final value |
|---|---|
| Target FPGA | Pango Logos2 `PG2L100H-6FBG676` |
| Implementation tool | PDS / Fabric Compiler 2025.2, build 211867 |
| CPU clock target | 100 MHz |
| Active performance profile | `CFG_PROFILE_C` |
| Processor configuration | I-cache on, D-cache on, branch predictor / BTB on |
| DebugCore / ILA directive | Not enabled in the final implementation |
| Final CPU Fmax | 104.0047 MHz |
| CPU setup / hold slack | +0.341 ns / +0.080 ns |
| Top-level design LUT / FF | 14,088 / 13,452 |
| DRM grid usage | 155 / 155 |

The final post-route implementation closes timing for the 100 MHz CPU domain.  See [IMPLEMENTATION_RESOURCE_REPORT.md](IMPLEMENTATION_RESOURCE_REPORT.md) for the complete post-PnR resource table, all clock-domain timing results, final bitstream hash, and the PDS evidence-file list.

## Repository layout

- `RV32_NES.pds` — PDS project entry point; source, constraint, and file-list paths are relative to this directory.
- `src/` — FPGA RTL, SoC integration, cache/BTB implementation, NES subsystem, and generated IP source files.
- `pds/` — board timing and physical constraints.
- `filelist/` — RTL file lists for review and command-line flows.
- `software/` — CoreMark/NES firmware sources, build scripts, ELF/BIN files, host-side utilities, and RAM initialisation files.
- `games/` — NES game images, SD-card image generation utilities, and `output.bin`.
- `bitstream/RV32_NES.sbit` — normal FPGA programming file without an inserted DebugCore.
- `debug/RV32_NES_debug.sbit` — DebugCore-enabled programming file.
- `debug/RV32_NES_debug_syn.fic` — Fabric Inserter / ILA probe configuration for a debug rebuild.

## Build and program

1. Open `RV32_NES.pds` with PDS 2025.2 and target the `PG2L100H-6FBG676` device.
2. The final directives are:

   ```text
   SYNTHESIS CFG_BOARD_APP_PRIMITIVE_INIT CFG_CPU_100MHZ CFG_PROFILE_C
   ```

3. Run Compile, Synthesize, Device Map, Place, Route, Route Optimize, Report Timing, and Generate Bitstream.
4. Program the generated `.sbit` to the FPGA board.  The final PDS run writes its programming file to `prj_tasks/pnr_1/generate_bitstream/RV32_NES.sbit`.

The normal and DebugCore builds are deliberately separate.  The final performance/resource configuration has no `CFG_ILA_PROBES` directive and does not insert a DebugCore.

## SD-card preparation

The NES game image is `games/output.bin`.  Write it to the target SD card using **Win32 Disk Imager**:

1. Back up the target card; writing the image overwrites the selected device.
2. Select `games/output.bin` as the image file.  If the picker filters for `.img`, choose `All files (*.*)`; do not rename or alter `output.bin`.
3. Verify the SD-card drive letter, click **Write**, and wait for completion.
4. Safely eject the card before placing it in the board.

## CoreMark report and NES handoff

After programming the FPGA and connecting its UART, run the host utility:

```powershell
cd .\software\board_app
py .\rv32_benchmark_then_nes.py --port COM9 --save-report .\board_report
```

Replace `COM9` with the board UART port.  The utility receives and saves the CoreMark/performance report, acknowledges a valid report, and then opens the NES keyboard-control window.  Press `Esc` to close it.

For a report-only run without the NES control window:

```powershell
cd .\software\board_app
py .\rv32_benchmark_then_nes.py --port COM9 --save-report .\board_report --no-gui
```

Do not pass `--manifest` for a normal demonstration unless a manifest was created for the exact programmed build; manifest checking intentionally rejects mismatched but otherwise valid builds.

## Detailed documents

- [IMPLEMENTATION_RESOURCE_REPORT.md](IMPLEMENTATION_RESOURCE_REPORT.md) — final post-route resource, timing, and bitstream evidence.
- [README_SUBMISSION.md](README_SUBMISSION.md) — original submission-package operating notes, including DebugCore relocation guidance.

Generated logs, old task backups, historical audit reports, and tool lock files are intentionally excluded from the repository.
