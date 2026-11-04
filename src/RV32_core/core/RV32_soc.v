// Connects the processor core to system memory and memory-mapped interfaces.
// Routes transactions, clock-domain connections, interrupts, and performance outputs.


`include "config.vh"
`include "../perf/perf_defs.vh"

module RV32_soc #(
  parameter ENABLE_NES_MASTER = 1'b0,
  parameter USE_INTERNAL_NES = 1'b0,
  parameter SYSTEM_CLOCK_100MHZ = 1'b0,
  parameter DUAL_CLOCK = 1'b0
) (
  input wire clk,  // Clock used for synchronous state updates.
  input tri0 peripheral_clk,  // Memory primitive configuration pin tri0.
  input wire reset_ext,  // Provides reset ext for this module.
  output wire reset,  // Resets the local state and pipeline registers.
  
  input wire [31:0] hrdataext,  // Provides hrdataext for this module.
  input wire hreadyext,  // AHB transfer-ready handshake.
  input wire hrespext,  // AHB transfer error/response status.
  output wire hselext,  // Provides hselext for this module.
  
  input wire external_hold,  // External backpressure request that suspends pipeline progression.
  
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
  output wire hready /* synthesis PAP_MARK_DEBUG="true" */,  // AHB transfer-completion handshake from the selected slave.
  
  
  input tri0 [31:0] nes_haddr,  // AHB address for the active transfer.
  input tri0 [31:0] nes_hwdata,  // AHB write data.
  input tri0 [3:0] nes_hwstrb,  // Memory primitive configuration pin tri0.
  input tri0 nes_hwrite,  // AHB read/write direction.
  input tri0 [2:0] nes_hsize,  // Memory primitive configuration pin tri0.
  input tri0 [2:0] nes_hburst,  // AHB burst encoding.
  input tri0 [3:0] nes_hprot,  // Memory primitive configuration pin tri0.
  input tri0 [1:0] nes_htrans,  // AHB transfer-type control.
  input tri0 nes_hmastlock,  // Memory primitive configuration pin tri0.
  output wire [31:0] nes_hrdata,  // Provides nes hrdata for this module.
  output wire nes_hready,  // AHB transfer-ready handshake.
  output wire nes_hresp,  // AHB transfer error/response status.
  output wire [15:0] nes_audio_sample,  // Provides nes audio sample for this module.
  output wire nes_audio_enable,  // Provides nes audio enable for this module.
  
  input wire [31:0] gpioin,  // Provides gpioin for this module.
  output wire [31:0] gpioout,  // Provides gpioout for this module.
  output wire [31:0] gpioen,  // Provides gpioen for this module.
  input wire uart_sin,  // Provides uart sin for this module.
  output wire UARTSout,  // Provides UARTSout for this module.
  input tri0 [15:0] serial_buttons,  // Memory primitive configuration pin tri0.
  input tri0 warm_boot,  // Memory primitive configuration pin tri0.
  output wire game_mode_status,  // Provides game mode status for this module.
  output wire menu_ready,  // Provides menu ready for this module.
  input tri0 video_test,  // Memory primitive configuration pin tri0.
  output wire [7:0] video_trace,  // Provides video trace for this module.
  input tri1 [2:0] board_buttons_n,  // Memory primitive configuration pin tri1.
  input tri0 hdmi_clk,  // Memory primitive configuration pin tri0.
  input tri1 hdmi_init,  // Memory primitive configuration pin tri1.
  output wire hdmi_pclk,  // Provides hdmi pclk for this module.
  output wire hdmi_vs,  // Provides hdmi vs for this module.
  output wire hdmi_hs,  // Provides hdmi hs for this module.
  output wire hdmi_de,  // Provides hdmi de for this module.
  output wire [23:0] hdmi_data,  // Provides hdmi data for this module.
  output wire sd_clk,  // Provides sd clk for this module.
  output wire sd_cmd,  // Provides sd cmd for this module.
  input tri1 sd_data0,  // Memory primitive configuration pin tri1.
  output wire sd_data3,  // Provides sd data3 for this module.
  output wire [7:0] joypad_led  // Provides joypad led for this module.
);

  
  wire [31:0] hrdata;           
  wire hresp /* synthesis PAP_MARK_DEBUG="true" */;            
  wire m_timer_int;
  wire m_sw_int;
  wire [63:0] mtime_clint;
  wire m_ext_int;
  wire slow_m_timer_int_node;
  wire slow_m_sw_int_node;
  wire [63:0] slow_mtime_clint_node;
  wire slow_m_ext_int_node;
  wire [31:0] status_flags_node, nes_flags_node, joypad_buttons_node;
  wire [15:0] serial_joypads_node;
  wire [7:0] combined_led_node;
  wire game_mode_node;
  wire [8:0] nes_cycle_node, nes_scanline_node;
  wire [5:0] nes_color_node;
  wire [15:0] internal_nes_sample_node;
  wire perf_window_marker_node /* synthesis PAP_MARK_DEBUG="true" */;
  wire perf_window_active_node /* synthesis PAP_MARK_DEBUG="true" */;
  wire [(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH)-1:0] perf_snapshot_counters_node;
  wire [`PERF_COUNTER_COUNT-1:0] perf_snapshot_overflow_node;
  wire [31:0] perf_snapshot_id_node;
  wire perf_snapshot_valid_node;
  wire perf_snapshot_done_node;
  wire [31:0] internal_nes_haddr_node, internal_nes_local_haddr_node;
  wire [31:0] internal_nes_hwdata_node;
  wire [3:0] internal_nes_hwstrb_node;
  wire internal_nes_hwrite_node;
  wire [2:0] internal_nes_hsize_node;
  wire [1:0] internal_nes_htrans_node;
  wire internal_nes_bus_error_node;

  
  wire slow_clk = DUAL_CLOCK ? peripheral_clk : clk;
  wire cpu_reset_n /* synthesis PAP_MARK_DEBUG="true" */;
  wire slow_reset_n;
  nes_reset_sync cpu_reset_sync_u(
    .clk(clk), .arst_n(~reset_ext), .rst_n(cpu_reset_n));
  nes_reset_sync slow_reset_sync_u(
    .clk(slow_clk), .arst_n(~reset_ext), .rst_n(slow_reset_n));
  assign reset = ~cpu_reset_n;

  // Select the configured hardware implementation.
  // Elaborate the selected parameter-dependent hardware structure.
  generate
    if (USE_INTERNAL_NES) begin : internal_nes_gen
      NES_AHB_interface nes_engine_u (
        .clk_21MHZ(slow_clk), .HRESP(nes_hresp),
        .bus_error(internal_nes_bus_error_node),
        .rst_n(slow_reset_n & status_flags_node[0]),
        .mapper_flags(nes_flags_node), .sample(internal_nes_sample_node),
        .color(nes_color_node), .joypad_p1(serial_joypads_node[7:0]),
        .joypad_p2(serial_joypads_node[15:8]), .audio_channels(5'b11111),
        .cycle(nes_cycle_node), .scanline(nes_scanline_node),
        .HADDR(internal_nes_local_haddr_node), .HWDATA(internal_nes_hwdata_node),
        .HRDATA(nes_hrdata), .HWRITE(internal_nes_hwrite_node),
        .HREADY(nes_hready), .HTRANS(internal_nes_htrans_node),
        .HSIZE(internal_nes_hsize_node));
      assign internal_nes_hwstrb_node = internal_nes_hwrite_node ?
          (4'b0001 << internal_nes_haddr_node[1:0]) : 4'b0000;
      
      
      // Select the address associated with the active request.
      assign internal_nes_haddr_node = 32'h4000_0000 | internal_nes_local_haddr_node;
    end else begin : no_internal_nes_gen
      assign internal_nes_haddr_node = 32'b0;
      assign internal_nes_local_haddr_node = 32'b0;
      assign internal_nes_hwdata_node = 32'b0;
      assign internal_nes_hwstrb_node = 4'b0;
      assign internal_nes_hwrite_node = 1'b0;
      assign internal_nes_hsize_node = 3'b000;
      assign internal_nes_htrans_node = 2'b00;
      assign internal_nes_sample_node = 16'h8000;
      assign nes_cycle_node = 9'b0;
      assign nes_scanline_node = 9'b0;
      assign nes_color_node = 6'b0;
      assign internal_nes_bus_error_node = 1'b0;
    end
  endgenerate

  assign nes_audio_sample = internal_nes_sample_node;
  assign nes_audio_enable = status_flags_node[0];
  assign joypad_led = combined_led_node;
  assign game_mode_status = game_mode_node;
  // Qualify transfer completion with the bus handshake.
  assign menu_ready = status_flags_node[1];

  
  rv32_level_sync timer_irq_sync_u(
    .clk(clk), .reset_n(cpu_reset_n), .async_level(slow_m_timer_int_node),
    .sync_level(m_timer_int));
  rv32_level_sync software_irq_sync_u(
    .clk(clk), .reset_n(cpu_reset_n), .async_level(slow_m_sw_int_node),
    .sync_level(m_sw_int));
  rv32_level_sync external_irq_sync_u(
    .clk(clk), .reset_n(cpu_reset_n), .async_level(slow_m_ext_int_node),
    .sync_level(m_ext_int));
  
  
  nes_cdc_mailbox #(.WIDTH(64)) mtime_cdc_u(
    .src_clk(slow_clk), .src_rst_n(slow_reset_n),
    .src_data(slow_mtime_clint_node),
    .dst_clk(clk), .dst_rst_n(cpu_reset_n),
    .dst_data(mtime_clint));

  
  // Instantiate the processor with system-level memory and interrupt signals.
  // Integrate fetch, execution, memory, privilege, and AHB control paths.
  RV32_core  core_u(.clk(clk), .reset(reset),
    .m_timer_int(m_timer_int), .m_ext_int(m_ext_int), .m_sw_int(m_sw_int), .mtime_clint(mtime_clint),
    .hrdata(hrdata), .hready(hready), .hresp(hresp), .hclk(hclk), .hrese_tn(hrese_tn), .haddr(haddr), .hwdata(hwdata), .hwstrb(hwstrb),
    .hwrite(hwrite), .hsize(hsize), .hburst(hburst), .hprot(hprot), .htrans(htrans), .hmastlock(hmastlock), .external_hold(external_hold),
    .perf_window_marker(perf_window_marker_node),
    .perf_window_active(perf_window_active_node),
    .perf_snapshot_counters(perf_snapshot_counters_node),
    .perf_snapshot_overflow(perf_snapshot_overflow_node),
    .perf_snapshot_id(perf_snapshot_id_node),
    .perf_snapshot_valid(perf_snapshot_valid_node),
    .perf_snapshot_done(perf_snapshot_done_node));

  
  wire main_hsel_node;
  wire perf_hsel_node;
  wire io_hsel_node;
  wire [31:0] main_hrdata_node;
  wire main_hready_node;
  wire main_hresp_node;
  wire [31:0] perf_hrdata_node;
  wire perf_hready_node;
  wire perf_hresp_node;
  wire [31:0] io_hrdata_node;
  wire io_hready_node;
  wire io_hresp_node;

  wire [31:0] slow_cpu_haddr_node;
  wire [31:0] slow_cpu_hwdata_node;
  wire [3:0] slow_cpu_hwstrb_node;
  wire [1:0] slow_cpu_htrans_node;
  wire slow_cpu_hwrite_node;
  wire [2:0] slow_cpu_hsize_node;
  wire [2:0] slow_cpu_hburst_node;
  wire [3:0] slow_cpu_hprot_node;
  wire [31:0] slow_cpu_hrdata_node;
  wire slow_cpu_hready_node;
  wire slow_cpu_hresp_node;

  rv32_ahb_data_router cpu_address_router_u(
    .clk(clk), .reset_n(cpu_reset_n),
    .cpu_haddr(haddr), .cpu_htrans(htrans),
    .cpu_hready(hready),
    .ram_hrdata(main_hrdata_node), .ram_hready(main_hready_node),
    .ram_hresp(main_hresp_node),
    .perf_hrdata(perf_hrdata_node), .perf_hready(perf_hready_node),
    .perf_hresp(perf_hresp_node),
    .io_hrdata(io_hrdata_node), .io_hready(io_hready_node),
    .io_hresp(io_hresp_node),
    .ram_hsel(main_hsel_node), .perf_hsel(perf_hsel_node), .io_hsel(io_hsel_node),
    .cpu_hrdata(hrdata), .cpu_hreadyout(hready),
    .cpu_hresp(hresp));

  // Provide the local AHB-attached program and data memory.
  // Provide the backing memory used by this datapath or prediction table.
  ram_ahb #(.BASE(`CFG_UNCORE_RAM_BASE)) cpu_main_ram_u (
    .hclk(clk), .hrese_tn(cpu_reset_n),
    .hsel_ram(main_hsel_node), .haddr(haddr),
    .hwrite(hwrite), .hready(hready),
    .htrans(htrans), .hwdata(hwdata),
    .hwstrb(hwstrb), .hread_ram(main_hrdata_node),
    .hresp_ram(main_hresp_node), .hready_ram(main_hready_node));

  // Expose performance control and snapshot data through AHB registers.
  perf_mmio_ahb #(.BASE(`CFG_PERF_BASE)) perf_mmio_u (
    .clk(clk), .reset_n(cpu_reset_n), .hsel(perf_hsel_node),
    .hready(hready), .haddr(haddr), .htrans(htrans),
    .hwrite(hwrite), .hsize(hsize), .hwdata(hwdata),
    .hwstrb(hwstrb), .hrdata(perf_hrdata_node),
    .hreadyout(perf_hready_node), .hresp(perf_hresp_node),
    .window_marker(perf_window_marker_node),
    .window_active(perf_window_active_node),
    .snapshot_values(perf_snapshot_counters_node),
    .snapshot_overflow(perf_snapshot_overflow_node),
    .snapshot_id(perf_snapshot_id_node),
    .snapshot_valid(perf_snapshot_valid_node),
    .snapshot_done(perf_snapshot_done_node));

  rv32_ahb_async_bridge cpu_peripheral_cdc_u (
    .s_clk(clk), .s_reset_n(cpu_reset_n), .s_hsel(io_hsel_node),
    .s_hready(hready), .s_haddr(haddr), .s_htrans(htrans),
    .s_hwrite(hwrite), .s_hsize(hsize), .s_hprot(hprot),
    .s_hwdata(hwdata), .s_hwstrb(hwstrb),
    .s_hrdata(io_hrdata_node), .s_hreadyout(io_hready_node),
    .s_hresp(io_hresp_node),
    .m_clk(slow_clk), .m_reset_n(slow_reset_n),
    .m_haddr(slow_cpu_haddr_node), .m_htrans(slow_cpu_htrans_node),
    .m_hwrite(slow_cpu_hwrite_node), .m_hsize(slow_cpu_hsize_node),
    .m_hburst(slow_cpu_hburst_node), .m_hprot(slow_cpu_hprot_node),
    .m_hwdata(slow_cpu_hwdata_node), .m_hwstrb(slow_cpu_hwstrb_node),
    .m_hrdata(slow_cpu_hrdata_node), .m_hready(slow_cpu_hready_node),
    .m_hresp(slow_cpu_hresp_node));

  
  // Select this hardware path from the active configuration.
  if (`CFG_BUS_SUPPORTED) begin : uncoregen 
    rv32_ahb_matrix_subsystem #(
      .ENABLE_NES_MASTER(ENABLE_NES_MASTER),
      .SYSTEM_CLOCK_100MHZ(SYSTEM_CLOCK_100MHZ)
    ) matrix_subsystem_u (
      .clk(slow_clk), .reset_n(slow_reset_n),
      .cpu_haddr(slow_cpu_haddr_node), .cpu_htrans(slow_cpu_htrans_node),
      .cpu_hwrite(slow_cpu_hwrite_node), .cpu_hsize(slow_cpu_hsize_node),
      .cpu_hburst(slow_cpu_hburst_node), .cpu_hprot(slow_cpu_hprot_node),
      .cpu_hwdata(slow_cpu_hwdata_node), .cpu_hwstrb(slow_cpu_hwstrb_node),
      .cpu_hmastlock(1'b0), .cpu_hrdata(slow_cpu_hrdata_node),
      .cpu_hready(slow_cpu_hready_node), .cpu_hresp(slow_cpu_hresp_node),
      .nes_haddr(USE_INTERNAL_NES ? internal_nes_haddr_node : nes_haddr),
      .nes_htrans(USE_INTERNAL_NES ? internal_nes_htrans_node : nes_htrans),
      .nes_hwrite(USE_INTERNAL_NES ? internal_nes_hwrite_node : nes_hwrite),
      .nes_hsize(USE_INTERNAL_NES ? internal_nes_hsize_node : nes_hsize),
      .nes_hburst(USE_INTERNAL_NES ? 3'b000 : nes_hburst),
      .nes_hprot(USE_INTERNAL_NES ? 4'b0011 : nes_hprot),
      .nes_hwdata(USE_INTERNAL_NES ? internal_nes_hwdata_node : nes_hwdata),
      .nes_hwstrb(USE_INTERNAL_NES ? internal_nes_hwstrb_node : nes_hwstrb),
      .nes_hmastlock(USE_INTERNAL_NES ? 1'b0 : nes_hmastlock),
      .nes_hrdata(nes_hrdata),
      .nes_hready(nes_hready), .nes_hresp(nes_hresp),
      .gpioin(gpioin), .gpioout(gpioout), .gpioen(gpioen),
      .uart_rx(uart_sin), .uart_tx(UARTSout),
      .serial_buttons(serial_buttons), .board_buttons_n(board_buttons_n),
      .warm_boot(warm_boot), .video_test(video_test), .video_trace(video_trace),
      .nes_cycle(nes_cycle_node), .nes_scanline(nes_scanline_node),
      .nes_color(nes_color_node), .serial_joypads(serial_joypads_node),
      .combined_led(combined_led_node), .game_mode(game_mode_node),
      .hdmi_clk(hdmi_clk), .hdmi_init(hdmi_init),
      .hdmi_pclk(hdmi_pclk), .hdmi_vs(hdmi_vs),
      .hdmi_hs(hdmi_hs), .hdmi_de(hdmi_de),
      .hdmi_data(hdmi_data), .sd_clk(sd_clk),
      .sd_cmd(sd_cmd), .sd_data0(sd_data0),
      .sd_data3(sd_data3), .status_flags(status_flags_node),
      .nes_flags(nes_flags_node), .joypad_buttons(joypad_buttons_node),
      .m_timer_int(slow_m_timer_int_node), .m_sw_int(slow_m_sw_int_node),
      .m_ext_int(slow_m_ext_int_node), .mtime_clint(slow_mtime_clint_node));
  end else begin
    // Return bus readiness to the active requesting master.
    assign {hrdata, hready, hresp, nes_hrdata,
            nes_hready, nes_hresp} = 1'b0;
  end

  
  assign hselext = 1'b0;
endmodule
