# Final PDS Implementation and Bitstream Resource Report

## 1. Scope and build configuration

This report records the **final post-place-and-route implementation results** of the submitted `RV32_NES` hardware project.  It is based on the PDS-generated post-route database and bitstream-generation log; it is not a pre-synthesis estimate.

| Item | Value |
|---|---|
| Target FPGA | Pango Logos2 `PG2L100H-6FBG676` |
| Implementation tool | PDS / Fabric Compiler 2025.2, build 211867 |
| Top module | `RV32_NES` |
| Active build directives | `SYNTHESIS CFG_BOARD_APP_PRIMITIVE_INIT CFG_CPU_100MHZ CFG_PROFILE_C` |
| Cache / prediction configuration | `CFG_PROFILE_C`: I-cache enabled, D-cache enabled, branch predictor / BTB enabled |
| DebugCore / ILA build directive | Not enabled (`CFG_ILA_PROBES` is absent) |

The results below correspond to the non-DebugCore implementation that generated the final programming file.

## 2. Implementation completion status

| Step | Result | Evidence |
|---|---|---|
| Synthesis and device mapping | Completed | `prj_tasks/syn_1/` and `prj_tasks/pnr_1/device_map/` |
| Placement, routing and route optimization | Completed successfully | `place_route/run_route_optimize.log` records `Design 'RV32_NES' has been routed successfully.` |
| Post-PnR timing report | Completed | `prj_tasks/pnr_1/report_timing/` |
| Programming-file generation | Completed successfully | `generate_bitstream/run.log` records `Generating Programming File done.` |

## 3. Final post-route resource utilization

### 3.1 Top-level entity accounting

The PDS `route_opt_resource_utilization` report attributes the following resources to the top-level `RV32_NES` entity.

| Resource | Used | Device available | Utilization |
|---|---:|---:|---:|
| LUT | 14,088 | 66,600 | 21.15% |
| FF | 13,452 | 133,200 | 10.10% |
| Distributed RAM | 304 | 19,900 | 1.53% |
| DRM grid | 155 | 155 | 100.00% |
| APM | 4 | 240 | 1.67% |
| GPLL | 4 | 6 | 66.67% |
| IO | 57 | 300 | 19.00% |
| CCS | 1 | 1 | 100.00% |
| RCKB | 1 | 24 | 4.17% |
| USCM | 4 | 32 | 12.50% |

### 3.2 Physical fabric breakdown

The final `route_opt_resource_usage` report additionally breaks resource occupancy down by physical logic-cell type.  It reports 3,953 CLMA cells (34%) and 1,406 CLMS cells (29%).

| Physical category | Used | Available | Utilization |
|---|---:|---:|---:|
| CLMA cells | 3,953 | 11,675 | 34% |
| CLMS cells | 1,406 | 4,975 | 29% |
| CLMA LUT entries | 11,847 | 46,700 | 26% |
| CLMS LUT entries | 4,721 | 19,900 | 24% |
| DRM18K | 28 | 310 | 10% |
| DRM36K | 141 | 155 | 91% |
| Total DRM grid | 155 | 155 | 100% |

The top-level LUT total in Section 3.1 and the CLMA/CLMS LUT entries in Section 3.2 are intentionally reported separately: PDS uses different accounting scopes for hierarchical entity resources and physical fabric categories (the latter includes categories such as constant and bypass LUT use).  Therefore these two LUT figures must not be added together or substituted for each other.

## 4. Post-route timing closure

All listed synchronous setup and hold endpoint counts are zero-fail after routing.

| Clock domain | Requested frequency | Post-route Fmax | Setup WNS | Setup TNS | Hold WHS | Setup status |
|---|---:|---:|---:|---:|---:|---|
| `CPU_CLK` | 100.0001 MHz | 104.0047 MHz | +0.341 ns | 0.000 ns | +0.080 ns | PASS |
| `CLK_42MHz` | 42.8786 MHz | 60.1704 MHz | +6.702 ns | 0.000 ns | +0.099 ns | PASS |
| `CLK_148p5MHz` | 148.5001 MHz | 165.1800 MHz | +0.680 ns | 0.000 ns | +0.166 ns | PASS |
| `CLK_49p152MHz` | 49.1520 MHz | 369.5481 MHz | +17.639 ns | 0.000 ns | +0.144 ns | PASS |
| `SD_SPI` | 10.7197 MHz | 142.0042 MHz | +43.122 ns | 0.000 ns | +0.106 ns | PASS |

The `CPU_CLK` result is the primary timing result for the 100 MHz RV32 processor domain: it has positive setup and hold slack after routing.

## 5. Final programming file

| Item | Value |
|---|---|
| Generated file | `prj_tasks/pnr_1/generate_bitstream/RV32_NES.sbit` |
| Generation time | 2026-11-05 10:04:43 (UTC+08:00) |
| File size | 3,791,112 bytes (3.615 MiB) |
| SHA-256 | `478C6222B6AA7E4429880679A27C5D57DD6A8717D849313430A1B5CC1397DD57` |

## 6. Evidence files

The following PDS outputs are retained in the local implementation workspace and are the source of the values in this report:

- `prj_tasks/pnr_1/place_route/report_db/route_opt_resource_usage.db`
- `prj_tasks/pnr_1/place_route/report_db/route_opt_resource_utilization.db`
- `prj_tasks/pnr_1/report_timing/report_db/report_timing_fmax.db`
- `prj_tasks/pnr_1/report_timing/report_db/report_timing_slow_setup.db`
- `prj_tasks/pnr_1/report_timing/report_db/report_timing_slow_hold.db`
- `prj_tasks/pnr_1/generate_bitstream/run.log`

This report was prepared from the implementation outputs generated on 2026-11-05.  No re-synthesis, re-place-and-route, or re-generation was performed while preparing this document.
