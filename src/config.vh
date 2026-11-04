// Function: ISA options, cache geometry and physical address-map configuration for a fixed RV32 machine-mode core.
// Architectural/address/AHB widths are fixed in RTL; M-mode encoding is 2'b11.
// Physical region bases are still required for RAM, ROM and MMIO decoding.

`ifndef RV32_CFG_CONSTANTS_VH
`define RV32_CFG_CONSTANTS_VH


`ifndef CFG_M_SUPPORTED
`define CFG_M_SUPPORTED                (1)
`endif
`ifndef CFG_ZMMUL_SUPPORTED
`define CFG_ZMMUL_SUPPORTED            (0)
`endif
`ifndef CFG_ZCA_SUPPORTED
`define CFG_ZCA_SUPPORTED              (0)
`endif
`ifndef CFG_ZBA_SUPPORTED
`define CFG_ZBA_SUPPORTED              (1)
`endif
`ifndef CFG_ZBB_SUPPORTED
`define CFG_ZBB_SUPPORTED              (1)
`endif
`ifndef CFG_ZBC_SUPPORTED
`define CFG_ZBC_SUPPORTED              (1)
`endif
`ifndef CFG_ZBS_SUPPORTED
`define CFG_ZBS_SUPPORTED              (1)
`endif

`define CFG_B_SUPPORTED                (`CFG_ZBA_SUPPORTED & `CFG_ZBB_SUPPORTED & `CFG_ZBS_SUPPORTED)
`define CFG_C_SUPPORTED                (`CFG_ZCA_SUPPORTED)
`define CFG_ZICSR_SUPPORTED            (1)
`define CFG_ZIFENCEI_SUPPORTED         (1)
`define CFG_ZICNTR_SUPPORTED           (1)
`define CFG_ZIHPM_SUPPORTED            (0)

// Independent read-only performance monitor. This does not change the
// architectural CSR counter configuration above.
`ifndef CFG_PERF_ENABLE
`define CFG_PERF_ENABLE                (1)
`endif
`define CFG_PERF_BASE                  (32'h30000000)
`define CFG_PERF_RANGE                 (32'h00000FFF)

// RV32 MXL plus the implemented base/extension bits.
`define CFG_MISA (32'h40000100 | \
                  (`CFG_B_SUPPORTED ? 32'h00000002 : 32'h00000000) | \
                  (`CFG_C_SUPPORTED ? 32'h00000004 : 32'h00000000) | \
                  (`CFG_M_SUPPORTED ? 32'h00001000 : 32'h00000000))

`define CFG_COUNTERS                   (12'd3)
`define CFG_VECTORED_INTERRUPTS_SUPPORTED (1)

// CoreMark hardware profiles, selected by exactly one PDS compiler directive.
// A: no I/D cache, no dynamic prediction (sequential fetch + EX recovery).
// B: I/D cache enabled, no dynamic prediction.
// C: I/D cache + complete GShare/PHT/BTB/RAS dynamic prediction.
// When no CFG_PROFILE_* is supplied, preserve the original all-enabled build.
// Do not combine profile directives or override the controlled macros in PDS.
`ifdef CFG_PROFILE_A
  `define CFG_ICACHE_SUPPORTED         (0)
  `define CFG_DCACHE_SUPPORTED         (0)
  `define CFG_BRANCH_PREDICTOR_ENABLE (0)
`elsif CFG_PROFILE_B
  `define CFG_ICACHE_SUPPORTED         (1)
  `define CFG_DCACHE_SUPPORTED         (1)
  `define CFG_BRANCH_PREDICTOR_ENABLE (0)
`elsif CFG_PROFILE_C
  `define CFG_ICACHE_SUPPORTED         (1)
  `define CFG_DCACHE_SUPPORTED         (1)
  `define CFG_BRANCH_PREDICTOR_ENABLE (1)
`endif

`ifndef CFG_BRANCH_PREDICTOR_ENABLE
`define CFG_BRANCH_PREDICTOR_ENABLE     (1)
`endif

`ifndef CFG_ICACHE_SUPPORTED
`define CFG_ICACHE_SUPPORTED           (1)
`endif
`ifndef CFG_DCACHE_SUPPORTED
`define CFG_DCACHE_SUPPORTED           (1)
`endif
`define CFG_ICACHE_NUMWAYS             (32'd2)
`define CFG_ICACHE_LINELENINBITS       (32'd128)
`define CFG_ICACHE_WAYSIZEINBYTES      (32'd2048)
`define CFG_DCACHE_NUMWAYS             (32'd2)
`define CFG_DCACHE_LINELENINBITS       (32'd128)
`define CFG_DCACHE_WAYSIZEINBYTES      (32'd2048)

`define CFG_IDIV_BITSPERCYCLE          (32'd2)
`define CFG_BURST_EN                    (1)
`define CFG_BUS_SUPPORTED              (1)
`define CFG_USE_SRAM                    (0)

`define CFG_RESET_VECTOR               (32'h80000000)
`define CFG_UNCORE_RAM_BASE            (32'h80000000)
`define CFG_UNCORE_RAM_BYTES           (32'd49152)
`ifndef CFG_UNCORE_RAM_SUPPORTED
`define CFG_UNCORE_RAM_SUPPORTED       (1)
`endif

`define CFG_BOOTROM_BASE               (32'h00001000)
`define CFG_BOOTROM_RANGE              (32'h00000FFF)
`define CFG_BOOTROM_PRELOAD            (1'b0)
`define CFG_BOOTROM_SUPPORTED          (0)
// CPU/NES shared RAM.  It is legal and idempotent, but deliberately
// non-cacheable so CPU accesses bypass I/D cache and remain coherent with NES.
`define CFG_EXT_MEM_BASE               (32'h40000000)
`define CFG_EXT_MEM_RANGE              (32'h0007FFFF)
`ifndef CFG_EXT_MEM_SUPPORTED
`define CFG_EXT_MEM_SUPPORTED          (1)
`endif
`define CFG_EXT_MEM_CACHEABLE          (0)
`define CFG_CLINT_BASE                 (32'h02000000)
`define CFG_CLINT_RANGE                (32'h0000FFFF)
`define CFG_CLINT_SUPPORTED            (1)
`define CFG_PLIC_BASE                  (32'h0C000000)
`define CFG_PLIC_RANGE                 (32'h03FFFFFF)
`define CFG_PLIC_SUPPORTED             (1)
`define CFG_PLIC_NUM_SRC               (32'd14)
`define CFG_PLIC_GPIO_ID               (32'd3)
`define CFG_PLIC_UART_ID               (32'd10)

`define CFG_UART_BASE                  (32'h10000400)
`define CFG_UART_RANGE                 (32'h00000007)
`define CFG_UART_SUPPORTED             (1)
`define CFG_UART_PRESCALE              (32'd1)
`define CFG_GPIO_BASE                  (32'h10060000)
`define CFG_GPIO_RANGE                 (32'h000000FF)
`define CFG_GPIO_SUPPORTED             (1)
`define CFG_GPIO_LOOPBACK_TEST         (1)
`define CFG_APB_BASE                   (32'h10000000)
`define CFG_APB_RANGE                  (32'h0000FFFF)
`define CFG_APB_SUPPORTED              (1)
`endif
