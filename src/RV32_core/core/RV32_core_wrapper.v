// Exposes the processor core through the system-facing interface.
// Passes clocks, reset, bus signals, and interrupt connections to the core.


`include "config.vh"
`include "../perf/perf_defs.vh"

module RV32_core_wrapper (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire m_timer_int,  // Machine timer interrupt request.
  input wire m_ext_int,  // Machine external interrupt request.
  input wire m_sw_int,  // Machine software interrupt request.
  input wire [63:0] mtime_clint,  // 64-bit machine timer value from the local interrupt timer.
  input wire [31:0] hrdata,  // AHB read-data bus returned by the selected target.
  input wire hready,  // AHB transfer-completion handshake from the selected slave.
  input wire hresp,  // AHB response status returned by the selected slave.
  output wire hclk,  // Clock forwarded to the AHB interface.
  output wire hrese_tn,  // Active-low AHB reset generated from the core reset.
  output wire [31:0] haddr,  // AHB byte address of the active bus transfer.
  output wire [31:0] hwdata,  // AHB write-data bus.
  output wire [3:0] hwstrb,  // Byte-lane strobes for the AHB write transaction.
  output wire hwrite,  // Indicates an AHB write transfer.
  output wire [2:0] hsize,  // AHB transfer size encoding.
  output wire [2:0] hburst,  // AHB burst-type encoding.
  output wire [3:0] hprot,  // AHB protection attributes.
  output wire [1:0] htrans,  // AHB transfer type for the selected bus request.
  output wire hmastlock,  // AHB locked-sequence indicator.
  input wire external_hold,  // External backpressure request that suspends pipeline progression.
  input wire perf_window_marker,  // Performance event or counter control.
  output wire perf_window_active,  // Performance event or counter control.
  output wire [(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH)-1:0] perf_snapshot_counters,  // Performance event or counter control.
  output wire [`PERF_COUNTER_COUNT-1:0] perf_snapshot_overflow,  // Performance event or counter control.
  output wire [31:0] perf_snapshot_id,  // Performance event or counter control.
  output wire perf_snapshot_valid,  // Performance event or counter control.
  output wire perf_snapshot_done  // Performance event or counter control.
);
  // Integrate fetch, execution, memory, privilege, and AHB control paths.
  RV32_core cpu_u (
    .clk(clk), .reset(reset),
    .m_timer_int(m_timer_int), .m_ext_int(m_ext_int), .m_sw_int(m_sw_int), .mtime_clint(mtime_clint),
    .hrdata(hrdata), .hready(hready), .hresp(hresp),
    .hclk(hclk), .hrese_tn(hrese_tn), .haddr(haddr), .hwdata(hwdata), .hwstrb(hwstrb),
    .hwrite(hwrite), .hsize(hsize), .hburst(hburst), .hprot(hprot), .htrans(htrans), .hmastlock(hmastlock), .external_hold(external_hold),
    .perf_window_marker(perf_window_marker),
    .perf_window_active(perf_window_active),
    .perf_snapshot_counters(perf_snapshot_counters),
    .perf_snapshot_overflow(perf_snapshot_overflow),
    .perf_snapshot_id(perf_snapshot_id),
    .perf_snapshot_valid(perf_snapshot_valid),
    .perf_snapshot_done(perf_snapshot_done));
endmodule
