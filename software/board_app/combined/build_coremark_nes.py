#!/usr/bin/env python3
# Modified for RV32 NES integration, 2026-11-01. See License/ for project notices.
"""Build the initial CoreMark-first, NES-second 48 KiB board image."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import subprocess
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[3]
HERE = pathlib.Path(__file__).resolve().parent
APP = ROOT / "software/board_app/app"
APP_SOURCE = APP / "source"
COREMARK = ROOT / "third_party/coremark"
import os
TOOLROOT = pathlib.Path(os.environ.get("RV32_RISCV_TOOLCHAIN", str(ROOT / "tools/riscv-gcc-15.2.0-1")))
DEFAULT_OUT_BASE = ROOT / "build/software_fusion/builds"

DEFAULT_ITERATIONS = 6000
RAM_BYTES = 48 * 1024
STACK_BYTES = 8 * 1024


def run(command: list[pathlib.Path | str], log: pathlib.Path) -> None:
    rendered = [str(item) for item in command]
    completed = subprocess.run(rendered, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    log.write_text("COMMAND: " + subprocess.list2cmdline(rendered) + "\n\n" +
                   completed.stdout, encoding="utf-8")
    if completed.returncode:
        raise RuntimeError(f"command failed ({completed.returncode}); see {log}")


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def project_relative(path: pathlib.Path) -> str:
    """Return a portable path relative to the checked-out project root."""
    return pathlib.Path(os.path.relpath(path.resolve(), ROOT.resolve())).as_posix()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=DEFAULT_ITERATIONS)
    parser.add_argument("--out", type=pathlib.Path)
    parser.add_argument("--layout", choices=("game-first", "coremark-first"),
                        default="game-first",
                        help="link placement experiment; does not change any object code")
    parser.add_argument("--cpu-hz", type=int, default=100_000_000)
    parser.add_argument("--seed3", type=lambda value: int(value, 0), default=0x66,
                        help="verification-only seed override; production uses 0x66")
    parser.add_argument("--enable-uart-report", action="store_true")
    arguments = parser.parse_args()
    if arguments.iterations <= 0:
        parser.error("--iterations must be positive")
    if arguments.cpu_hz <= 0:
        parser.error("--cpu-hz must be positive")
    iterations = arguments.iterations
    if arguments.out is None:
        build_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
        out = (DEFAULT_OUT_BASE / build_id).resolve()
    else:
        out = arguments.out.resolve()
    if out.exists():
        raise RuntimeError(f"refusing to overwrite evidence directory: {out}")
    objdir = out / "obj"
    objdir.mkdir(parents=True)

    gcc = next(TOOLROOT.rglob("riscv-none-elf-gcc.exe"))
    toolbin = gcc.parent
    objcopy = toolbin / "riscv-none-elf-objcopy.exe"
    size = toolbin / "riscv-none-elf-size.exe"
    readelf = toolbin / "riscv-none-elf-readelf.exe"
    nm = toolbin / "riscv-none-elf-nm.exe"

    common = [
        "-ffunction-sections", "-fdata-sections",
        "-fno-unwind-tables", "-fno-asynchronous-unwind-tables",
        "-march=rv32im_zicsr_zifencei_zba_zbb_zbc_zbs", "-mabi=ilp32",
        "-ffreestanding", "-fno-builtin", "-nostdlib", "-nostartfiles",
        "-static", "-g", f"-DITERATIONS={iterations}",
        f"-DCOMBINED_CPU_HZ={arguments.cpu_hz}ull",
        f"-DCOMBINED_SEED3={arguments.seed3}",
        f"-DCOMBINED_ENABLE_UART_REPORT={1 if arguments.enable_uart_report else 0}",
        "-DPERFORMANCE_RUN=1", "-DTOTAL_DATA_SIZE=2000",
        "-I", HERE, "-I", APP_SOURCE, "-I", COREMARK,
    ]

    # Keep the benchmark's measured code on its established performance flags,
    # but do not apply loop-unrolling to the graphics/menu code. Doing so makes
    # large pixel-copy loops explode in size without improving CoreMark.
    board_opt = ["-O2"]
    coremark_opt = [
        "-O3", "-mbranch-cost=1", "-funroll-all-loops",
        "--param=max-inline-insns-auto=200", "-finline-limit=10000",
        "-fno-code-hoisting", "-fno-if-conversion2",
        "-falign-functions=4", "-falign-jumps=4", "-falign-loops=4",
    ]

    sources: list[tuple[pathlib.Path, list[str]]] = [
        (APP / "start.S", board_opt),
        (APP / "runtime_memory.c", board_opt),
        (ROOT / "software/main.c", board_opt),
        (HERE / "coremark_port.c", board_opt),
        (HERE / "perf_monitor.c", board_opt),
        (HERE / "uart_report.c", board_opt),
        (APP_SOURCE / "graphics.c", board_opt),
        (APP_SOURCE / "interrupt_handlers.c", board_opt),
        (APP_SOURCE / "nes_menu.c", board_opt),
        (APP_SOURCE / "sd_card.c", board_opt),
        (APP_SOURCE / "uart.c", board_opt),
        (COREMARK / "core_main.c", [*coremark_opt, "-Dmain=benchmark_coremark_entry"]),
        (COREMARK / "core_list_join.c", coremark_opt),
        (COREMARK / "core_matrix.c", coremark_opt),
        (COREMARK / "core_state.c", coremark_opt),
        (COREMARK / "core_util.c", coremark_opt),
    ]

    identity_inputs = [source for source, _ in sources] + [
        HERE / "core_portme.h", HERE / "benchmark_result.h",
        HERE / "perf_monitor.h", HERE / "uart_report.h",
        HERE / "sections_48k.ld", pathlib.Path(__file__).resolve(),
    ]
    identity = hashlib.sha256()
    for identity_input in identity_inputs:
        identity.update(project_relative(identity_input).encode("utf-8"))
        identity.update(identity_input.read_bytes())
    identity.update(f"iterations={iterations};cpu_hz={arguments.cpu_hz};seed3={arguments.seed3};uart={arguments.enable_uart_report}".encode())
    build_id = int.from_bytes(identity.digest()[:4], "little")
    common.append(f"-DCOMBINED_BUILD_ID=0x{build_id:08x}u")

    objects: list[pathlib.Path] = []
    source_hashes: dict[str, str] = {}
    for index, (source, extra) in enumerate(sources):
        obj = objdir / f"{index:02d}_{source.stem}.o"
        run([gcc, *common, *extra, "-c", source, "-o", obj],
            out / f"compile_{index:02d}_{source.stem}.log")
        objects.append(obj)
        source_hashes[project_relative(source)] = sha256(source)

    build_inputs = [
        HERE / "core_portme.h",
        HERE / "benchmark_result.h",
        HERE / "perf_monitor.h",
        HERE / "uart_report.h",
        HERE / "sections_48k.ld",
        pathlib.Path(__file__).resolve(),
    ]
    for build_input in build_inputs:
        source_hashes[project_relative(build_input)] = sha256(build_input)

    # The first six objects contain startup, firmware, CoreMark port and telemetry. The
    # remaining groups can be placed in either order without recompilation;
    # this is useful for measuring PC-indexed I-cache/BTB/PHT layout effects.
    if arguments.layout == "coremark-first":
        link_objects = objects[:6] + objects[11:] + objects[6:11]
    else:
        link_objects = objects

    elf = out / "coremark_then_nes.elf"
    binary = out / "coremark_then_nes.bin"
    mapfile = out / "coremark_then_nes.map"
    run([gcc, *common, *link_objects, "-nostdlib", "-nostartfiles", "-static",
         "-Wl,--gc-sections", "-Wl,--no-relax", f"-Wl,-Map,{mapfile}",
         f"-Wl,-T,{HERE / 'sections_48k.ld'}", "-lgcc", "-o", elf],
        out / "link.log")
    run([objcopy, "-O", "binary", elf, binary], out / "objcopy.log")
    run([size, "-A", elf], out / "size_sections.txt")
    run([size, elf], out / "size_summary.txt")
    run([readelf, "-lW", elf], out / "program_headers.txt")
    run([nm, "-n", elf], out / "symbols.txt")

    image_size = binary.stat().st_size
    symbol_text = (out / "symbols.txt").read_text(encoding="utf-8")
    image_end_match = re.search(r"^([0-9a-fA-F]+)\s+\w\s+_image_end$", symbol_text, re.M)
    stack_limit_match = re.search(r"^([0-9a-fA-F]+)\s+\w\s+_stack_limit$", symbol_text, re.M)
    if not image_end_match or not stack_limit_match:
        raise RuntimeError("linker boundary symbols are missing")
    image_end = int(image_end_match.group(1), 16)
    stack_limit = int(stack_limit_match.group(1), 16)
    runtime_static_bytes = image_end - 0x80000000
    headroom_before_stack = stack_limit - image_end

    padded = binary.read_bytes() + bytes(RAM_BYTES - image_size)
    init_dir = out / "init"
    init_dir.mkdir()
    words = [f"{int.from_bytes(padded[offset:offset+4], 'little'):08x}"
             for offset in range(0, RAM_BYTES, 4)]
    for bank in range(6):
        (init_dir / f"bank{bank}.mem").write_text(
            "\n".join(words[bank * 2048:(bank + 1) * 2048]) + "\n",
            encoding="ascii")

    manifest = {
        "status": "PASS",
        "purpose": "initial CoreMark-first NES-second combined link",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "iterations": iterations,
        "link_layout": arguments.layout,
        "cpu_hz": arguments.cpu_hz,
        "seed3": arguments.seed3,
        "uart_report_enabled": arguments.enable_uart_report,
        "build_id": f"0x{build_id:08x}",
        "ram_bytes": RAM_BYTES,
        "reserved_stack_bytes": STACK_BYTES,
        "binary_bytes": image_size,
        "runtime_static_bytes_including_bss_and_alignment": runtime_static_bytes,
        "headroom_before_reserved_stack": headroom_before_stack,
        "image_end": f"0x{image_end:08x}",
        "stack_limit": f"0x{stack_limit:08x}",
        "compiler": project_relative(gcc),
        "compiler_version": subprocess.check_output([str(gcc), "--version"], text=True).splitlines()[0],
        "common_flags": [project_relative(item) if isinstance(item, pathlib.Path)
                         else str(item) for item in common],
        "board_optimization_flags": board_opt,
        "coremark_optimization_flags": coremark_opt,
        "elf": project_relative(elf),
        "elf_sha256": sha256(elf),
        "binary": project_relative(binary),
        "binary_sha256": sha256(binary),
        "map": project_relative(mapfile),
        "init_banks": project_relative(init_dir),
        "source_sha256": source_hashes,
        "limitations": [
            "link/size proof only; not executed on RTL or FPGA",
            "performance MMIO is linked into this image; execution is verified separately by the RTL smoke flow",
            "UART result framing is not connected yet",
            "existing Joypad_Input RTL and keyboard Python code are unchanged",
        ],
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    print((out / "size_summary.txt").read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
