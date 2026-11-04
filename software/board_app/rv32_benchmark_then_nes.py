#!/usr/bin/env python3
"""Receive one verified RV32 report, ACK it, then reuse the NES keyboard UI."""

from __future__ import annotations

import argparse
import json
import pathlib
import struct
import textwrap
import time
import zlib

MAGIC = b"RVPR"
REQUEST = b"\xa5"
ACK = 0x5A
NES_READY = b"NES_READY\n"
COUNTER_NAMES = (
    "cycles", "instret", "conditional_branches", "conditional_branch_misses",
    "all_cfi_misses", "icache_refill_done", "dcache_refill_done",
    "icache_access_observed", "dcache_access_observed", "frontend_hold_cycles",
    "fetch_path_wait_cycles", "icache_busy_cycles", "mem_path_wait_cycles",
    "dcache_busy_cycles", "division_busy_cycles", "dependency_stall_cycles",
    "icache_request_accept", "icache_miss_start", "dcache_load_accept",
    "dcache_load_miss_start", "dcache_store_accept", "dcache_store_miss_start",
    "dcache_writeback_start", "ahb_wait_cycles", "hold_excl_external",
    "hold_excl_wfi", "hold_excl_memory", "hold_excl_fetch",
    "hold_excl_division", "hold_excl_dependency", "hold_excl_other",
)

# These are the measured CoreMark translation-unit options used by the
# combined image builder.  Older manifests record the common options but not
# this module-specific list, so retain the exact historical list here as a
# display fallback.  This does not alter how the FPGA image was compiled.
COREMARK_OPT_FLAGS = (
    "-O3", "-mbranch-cost=1", "-funroll-all-loops",
    "--param=max-inline-insns-auto=200", "-finline-limit=10000",
    "-fno-code-hoisting", "-fno-if-conversion2",
    "-falign-functions=4", "-falign-jumps=4", "-falign-loops=4",
)


def read_exact(stream, length: int, deadline: float) -> bytes:
    result = bytearray()
    while len(result) < length:
        if time.monotonic() >= deadline:
            raise TimeoutError(f"wanted {length} bytes, received {len(result)}")
        result.extend(stream.read(length - len(result)))
    return bytes(result)


def receive_frame(stream, timeout: float) -> bytes:
    deadline = time.monotonic() + timeout
    sync = bytearray()
    while bytes(sync[-4:]) != MAGIC:
        sync.extend(read_exact(stream, 1, deadline))
        if len(sync) > 4:
            del sync[:-4]
    fixed = read_exact(stream, 12, deadline)
    version, frame_type, payload_length, _snapshot_id = struct.unpack("<HHII", fixed)
    if version != 1 or frame_type != 2 or payload_length > 1024:
        raise ValueError("unsupported report header")
    return MAGIC + fixed + read_exact(stream, payload_length + 4, deadline)


def wait_for_marker(stream, marker: bytes, timeout: float) -> None:
    """Consume the UART stream until an exact firmware phase marker arrives."""
    deadline = time.monotonic() + timeout
    matched = 0
    while matched < len(marker):
        value = read_exact(stream, 1, deadline)[0]
        if value == marker[matched]:
            matched += 1
        else:
            matched = 1 if value == marker[0] else 0


def check_manifest(report: dict, manifest_path: pathlib.Path | None) -> None:
    if manifest_path is None:
        return
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_build_id = str(manifest["build_id"]).lower()
    actual_build_id = str(report["build_id"]).lower()
    if actual_build_id != expected_build_id:
        raise ValueError(
            f"build-id mismatch: board={actual_build_id} manifest={expected_build_id}"
        )
    if report["cpu_hz"] != int(manifest["cpu_hz"]):
        raise ValueError("CPU frequency differs from the selected build manifest")
    if report["coremark"]["iterations"] != int(manifest["iterations"]):
        raise ValueError("iteration count differs from the selected build manifest")


def decode_report(frame: bytes) -> dict:
    if len(frame) < 20 or frame[:4] != MAGIC:
        raise ValueError("bad report magic/length")
    version, frame_type, payload_length, snapshot_id = struct.unpack_from("<HHII", frame, 4)
    if len(frame) != 16 + payload_length + 4:
        raise ValueError("payload length mismatch")
    expected_crc, = struct.unpack_from("<I", frame, len(frame) - 4)
    actual_crc = zlib.crc32(frame[:-4]) & 0xFFFFFFFF
    if expected_crc != actual_crc:
        raise ValueError(f"CRC32 mismatch expected={expected_crc:08x} actual={actual_crc:08x}")
    scalar = struct.unpack_from("<IIIIQIIIIIIIIII", frame, 16)
    (build_id, cpu_hz, size, iterations, ticks, total_seconds, seedcrc, crclist,
     crcmatrix, crcstate, crcfinal, validation, error_count, counter_count,
     overflow) = scalar
    if counter_count != len(COUNTER_NAMES):
        raise ValueError(f"counter count {counter_count} != {len(COUNTER_NAMES)}")
    offset = 16 + struct.calcsize("<IIIIQIIIIIIIIII")
    counters = struct.unpack_from(f"<{counter_count}Q", frame, offset)
    raw = dict(zip(COUNTER_NAMES, counters))
    def ratio(numerator: int, denominator: int):
        return None if denominator == 0 else numerator / denominator
    return {
        "protocol_version": version, "frame_type": frame_type,
        "snapshot_id": snapshot_id, "report_crc32": f"0x{expected_crc:08x}",
        "build_id": f"0x{build_id:08x}", "cpu_hz": cpu_hz,
        "coremark": {"size": size, "iterations": iterations, "ticks": ticks,
                     "seconds": ticks / cpu_hz, "iterations_per_sec": iterations * cpu_hz / ticks,
                     "coremark_per_mhz": iterations * 1_000_000 / ticks,
                     "reported_integer_seconds": total_seconds,
                     "seedcrc": f"0x{seedcrc:04x}", "crclist": f"0x{crclist:04x}",
                     "crcmatrix": f"0x{crcmatrix:04x}", "crcstate": f"0x{crcstate:04x}",
                     "crcfinal": f"0x{crcfinal:04x}", "validation": validation,
                     "error_count": error_count},
        "overflow_mask": f"0x{overflow:08x}", "raw_counters": raw,
        "derived": {"ipc": ratio(raw["instret"], raw["cycles"]),
                    "cpi": ratio(raw["cycles"], raw["instret"]),
                    "conditional_branch_miss_rate": ratio(raw["conditional_branch_misses"], raw["conditional_branches"]),
                    "icache_miss_rate": ratio(raw["icache_miss_start"], raw["icache_request_accept"]),
                    "dcache_load_miss_rate": ratio(raw["dcache_load_miss_start"], raw["dcache_load_accept"]),
                    "frontend_hold_rate": ratio(raw["frontend_hold_cycles"], raw["cycles"])},
    }


def load_manifest(manifest_path: pathlib.Path | None) -> dict:
    if manifest_path is None:
        return {}
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def _label(label: str, value) -> str:
    return f"{label:<31}: {value}"


def _wrapped_label(label: str, values: list[str]) -> list[str]:
    prefix = f"{label:<31}: "
    wrapped = textwrap.wrap(" ".join(str(value) for value in values),
                            width=112, initial_indent=prefix,
                            subsequent_indent=" " * len(prefix))
    return wrapped or [prefix]


def _decimal(value, places: int = 6) -> str:
    return "N/A" if value is None else f"{value:.{places}f}"


def _percent(value, places: int = 6) -> str:
    return "N/A" if value is None else f"{value * 100:.{places}f}%"


def render_summary(report: dict, manifest: dict) -> str:
    """Render the compact CoreMark-style console view.

    The UART frame stays binary and unchanged.  All rates below are computed
    on the PC from the received 64-bit raw counters.  The full decoded record
    is still saved separately as report.json.
    """
    coremark = report["coremark"]
    raw = report["raw_counters"]
    derived = report["derived"]
    validation_ok = coremark["validation"] == 1 and coremark["error_count"] == 0

    # The UART packet deliberately carries measured data only.  Build metadata
    # is trustworthy only when the caller supplied the matching manifest.
    manifest_supplied = bool(manifest)
    compiler = (manifest.get("compiler_version", "not recorded in selected manifest")
                if manifest_supplied else "not supplied (--manifest omitted)")
    common_flags = ([str(flag) for flag in manifest.get("common_flags", [])]
                    if manifest_supplied else ["not supplied (--manifest omitted)"])
    coremark_flags = ([str(flag) for flag in manifest.get("coremark_optimization_flags", [])]
                      if manifest_supplied else ["not supplied (--manifest omitted)"])
    ram_bytes = int(manifest.get("ram_bytes", 49152))
    memory_base = int(str(manifest.get("memory_base", "0x80000000")), 0)
    memory_end = memory_base + ram_bytes - 1
    memory_provenance = "" if manifest_supplied else "; default, manifest omitted"

    lines = [
        "CoreMark 1.0 result...",
        "2K performance run parameters for coremark.",
        _label("CoreMark Size", coremark["size"]),
        _label("Total ticks", coremark["ticks"]),
        _label("Total time (secs)", f'{coremark["seconds"]:.8f}'),
        _label("Iterations/Sec", f'{coremark["iterations_per_sec"]:.6f}'),
        _label("Iterations", coremark["iterations"]),
        _label("CoreMark/MHz", f'{coremark["coremark_per_mhz"]:.6f}'),
        _label("Compiler version", compiler),
    ]
    lines.extend(_wrapped_label("Compiler common flags", common_flags))
    lines.extend(_wrapped_label("CoreMark optimization flags", coremark_flags))
    lines.extend([
        _label("Memory location",
               f'SRAM {ram_bytes // 1024} KiB '
               f'(0x{memory_base:08x}-0x{memory_end:08x}{memory_provenance})'),
        _label("seedcrc", coremark["seedcrc"]),
        _label("[0]crclist", coremark["crclist"]),
        _label("[0]crcmatrix", coremark["crcmatrix"]),
        _label("[0]crcstate", coremark["crcstate"]),
        _label("[0]crcfinal", coremark["crcfinal"]),
        ("Correct operation validated. See README.md for run and reporting rules."
         if validation_ok else
         f'ERROR: CoreMark validation failed (validation={coremark["validation"]}, '
         f'errors={coremark["error_count"]}).'),
        "CoreMark 1.0 done...",
        _label("Snapshot ID", report["snapshot_id"]),
        _label("Build ID", report["build_id"]),
        _label("Report CRC32", report["report_crc32"]),
        _label("Counter overflow mask", report["overflow_mask"]),
        _label("Total cycles", raw["cycles"]),
        _label("Total retired instructions", raw["instret"]),
        _label("I-Cache Access", raw["icache_request_accept"]),
        _label("I-Cache Miss", raw["icache_miss_start"]),
        _label("D-Cache Load Access", raw["dcache_load_accept"]),
        _label("D-Cache Load Miss", raw["dcache_load_miss_start"]),
        _label("Conditional Branch Count", raw["conditional_branches"]),
        _label("Conditional Branch Miss", raw["conditional_branch_misses"]),
        _label("Stalled frontend cycles", raw["frontend_hold_cycles"]),
        _label("IPC", _decimal(derived["ipc"])),
        _label("CPI", _decimal(derived["cpi"])),
        _label("I-Cache miss rate", _percent(derived["icache_miss_rate"])),
        _label("D-Cache load miss rate", _percent(derived["dcache_load_miss_rate"], 8)),
        _label("Branch misprediction rate", _percent(derived["conditional_branch_miss_rate"])),
        _label("Stalled frontend rate", _percent(derived["frontend_hold_rate"])),
    ])
    return "\n".join(lines) + "\n"


def keyboard_window(serial_port) -> None:
    import pygame
    from two_players import snapshot
    from menu_controls import MenuControls
    pygame.init()
    screen = pygame.display.set_mode((900, 300))
    pygame.display.set_caption("NES serial: P1 + P2 (Esc exits)")
    font = pygame.font.Font(None, 28)
    mappings = ((pygame.K_j, pygame.K_k, pygame.K_u, pygame.K_i, pygame.K_w, pygame.K_s, pygame.K_a, pygame.K_d),
                (pygame.K_KP1, pygame.K_KP2, pygame.K_KP4, pygame.K_KP5, pygame.K_UP, pygame.K_DOWN, pygame.K_LEFT, pygame.K_RIGHT))
    menu, clock, running = MenuControls(), pygame.time.Clock(), True
    serial_port.write(snapshot(1, 0) + snapshot(2, 0))
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE): running = False
            if event.type == pygame.KEYDOWN and event.key == pygame.K_F1: menu.toggle()
        keys = pygame.key.get_pressed()
        states = [sum(1 << bit for bit, key in enumerate(mapping) if keys[key]) for mapping in mappings] if pygame.key.get_focused() else [0, 0]
        states[0] = menu.apply(states[0], time.monotonic()) if pygame.key.get_focused() else 0
        serial_port.write(snapshot(1, states[0]) + snapshot(2, states[1]))
        screen.fill((22, 27, 38))
        for index, line in enumerate(("P1: WASD / A=J B=K Select=U Start=I",
                                      "P2: Arrows / A=Num1 B=Num2 Select=Num4 Start=Num5",
                                      f"P1={states[0]:02X}  P2={states[1]:02X}")):
            screen.blit(font.render(line, True, (225, 232, 242)), (20, 30 + index * 45))
        pygame.display.flip(); clock.tick(50)
    serial_port.write(snapshot(1, 0) + snapshot(2, 0)); serial_port.flush(); pygame.quit()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--report-timeout", type=float, default=1800.0,
                        help="seconds to wait for the CoreMark report; no-cache runs can be much slower (default: 1800)")
    parser.add_argument("--save-report", type=pathlib.Path, default=pathlib.Path("board_report"))
    parser.add_argument("--decode-file", type=pathlib.Path)
    parser.add_argument("--no-gui", action="store_true")
    parser.add_argument("--verbose-json", action="store_true",
                        help="also print the complete decoded counter JSON")
    args = parser.parse_args()
    if args.report_timeout <= 0:
        parser.error("--report-timeout must be positive")
    if args.decode_file:
        frame = args.decode_file.read_bytes()
        report = decode_report(frame)
    else:
        if not args.port: parser.error("--port is required unless --decode-file is used")
        import serial
        with serial.Serial(args.port, args.baud, timeout=0.1, write_timeout=1) as port:
            port.reset_input_buffer()
            port.write(REQUEST); port.flush()
            frame = receive_frame(port, args.report_timeout)
            report = decode_report(frame)
            check_manifest(report, args.manifest)
            manifest = load_manifest(args.manifest)
            crc = int(report["report_crc32"], 16)
            args.save_report.mkdir(parents=True, exist_ok=True)
            (args.save_report / "raw.bin").write_bytes(frame)
            rendered_json = json.dumps(report, indent=2) + "\n"
            rendered_summary = render_summary(report, manifest)
            (args.save_report / "report.json").write_text(rendered_json, encoding="utf-8")
            (args.save_report / "summary.txt").write_text(rendered_summary, encoding="utf-8")
            (args.save_report / "terminal.log").write_text(rendered_summary, encoding="utf-8")
            print(rendered_summary, end="")
            if args.verbose_json:
                print("\nComplete decoded JSON:\n" + rendered_json, end="")
            # ACK is deliberately last: an unvalidated or unsaved report must not
            # permit the board to leave the report phase.
            ack = bytes((ACK,)) + struct.pack("<II", report["snapshot_id"], crc)
            for byte in ack:
                port.write(bytes((byte,))); port.flush(); time.sleep(0.003)
            wait_for_marker(port, NES_READY, 5.0)
            if not args.no_gui: keyboard_window(port)
            return 0
    args.save_report.mkdir(parents=True, exist_ok=True)
    check_manifest(report, args.manifest)
    manifest = load_manifest(args.manifest)
    rendered_json = json.dumps(report, indent=2) + "\n"
    rendered_summary = render_summary(report, manifest)
    (args.save_report / "report.json").write_text(rendered_json, encoding="utf-8")
    (args.save_report / "summary.txt").write_text(rendered_summary, encoding="utf-8")
    (args.save_report / "terminal.log").write_text(rendered_summary, encoding="utf-8")
    print(rendered_summary, end="")
    if args.verbose_json:
        print("\nComplete decoded JSON:\n" + rendered_json, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
    parser.add_argument("--manifest", type=pathlib.Path,
                        help="require board build-id/frequency/iterations to match this manifest")
