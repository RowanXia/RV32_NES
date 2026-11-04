// Modified for RV32 NES integration, 2026-11-01.
// Two-master/six-target AHB subsystem used by the RV32 CPU and reserved NES master.
// MI0 is a guarded legacy program-RAM aperture; the real 48-KiB RAM now stays
// beside the CPU in the fast clock domain. MI1 is display RAM; MI2 feeds the
// APB peripheral island; MI3 is shared NES RAM; MI4 is the SD controller; MI5
// remains reserved for Ethernet. Disabled/unmapped targets return AHB ERROR.
`include "../config.vh"

module rv32_ahb_matrix_subsystem #(
  parameter ENABLE_NES_MASTER = 1'b0,
  parameter SYSTEM_CLOCK_100MHZ = 1'b0
) (
  input  wire clk,
  input  wire reset_n,

  input  wire [31:0] cpu_haddr,
  input  wire [1:0]  cpu_htrans,
  input  wire        cpu_hwrite,
  input  wire [2:0]  cpu_hsize,
  input  wire [2:0]  cpu_hburst,
  input  wire [3:0]  cpu_hprot,
  input  wire [31:0] cpu_hwdata,
  input  wire [3:0]  cpu_hwstrb,
  input  wire        cpu_hmastlock,
  output wire [31:0] cpu_hrdata,
  output wire        cpu_hready,
  output wire        cpu_hresp,

  input  wire [31:0] nes_haddr,
  input  wire [1:0]  nes_htrans,
  input  wire        nes_hwrite,
  input  wire [2:0]  nes_hsize,
  input  wire [2:0]  nes_hburst,
  input  wire [3:0]  nes_hprot,
  input  wire [31:0] nes_hwdata,
  input  wire [3:0]  nes_hwstrb,
  input  wire        nes_hmastlock,
  output wire [31:0] nes_hrdata,
  output wire        nes_hready,
  output wire        nes_hresp,

  input  wire [31:0] gpioin,
  output wire [31:0] gpioout,
  output wire [31:0] gpioen,
  input  wire        uart_rx,
  output wire        uart_tx,
  input  wire [15:0] serial_buttons,
  input  wire        warm_boot,
  input  wire [8:0]  nes_cycle,
  input  wire [8:0]  nes_scanline,
  input  wire [5:0]  nes_color,
  output wire [15:0] serial_joypads,
  output wire [7:0] combined_led,
  output wire game_mode,
  input tri0 video_test,
  output wire [7:0] video_trace,
  input  wire [2:0]  board_buttons_n,
  input  wire        hdmi_clk,
  input  wire        hdmi_init,
  output wire        hdmi_pclk,
  output wire        hdmi_vs,
  output wire        hdmi_hs,
  output wire        hdmi_de,
  output wire [23:0] hdmi_data,
  output wire        sd_clk,
  output wire        sd_cmd,
  input  wire        sd_data0,
  output wire        sd_data3,
  output wire [31:0] status_flags,
  output wire [31:0] nes_flags,
  output wire [31:0] joypad_buttons,
  output wire        m_timer_int,
  output wire        m_sw_int,
  output wire        m_ext_int,
  output wire [63:0] mtime_clint
);
  wire [5:0] target_sel_node;
  wire [31:0] target_addr_node [0:5];
  wire [31:0] target_wdata_node [0:5];
  wire [31:0] target_rdata_node [0:5];
  wire [31:0] target_wuser_node [0:5];
  wire [1:0] target_trans_node [0:5];
  wire [2:0] target_size_node [0:5];
  wire [2:0] target_burst_node [0:5];
  wire [3:0] target_prot_node [0:5];
  wire [5:0] target_write_node;
  wire [5:0] target_ready_mux_node;
  wire [5:0] target_ready_out_node;
  wire [5:0] target_resp_node;

  AHB_Bridge_lite matrix_u (
    .HCLK(clk), .HRESETn(reset_n), .REMAP(4'b0),
    .HADDRCPU(cpu_haddr), .HTRANSCPU(cpu_htrans),
    .HWRITECPU(cpu_hwrite), .HSIZECPU(cpu_hsize),
    .HBURSTCPU(cpu_hburst), .HPROTCPU(cpu_hprot),
    .HWDATACPU(cpu_hwdata), .HMASTLOCKCPU(cpu_hmastlock),
    .HAUSERCPU(32'b0), .HWUSERCPU({28'b0, cpu_hwstrb}),
    .HADDRNES(ENABLE_NES_MASTER ? nes_haddr : 32'b0),
    .HTRANSNES(ENABLE_NES_MASTER ? nes_htrans : 2'b00),
    .HWRITENES(ENABLE_NES_MASTER ? nes_hwrite : 1'b0),
    .HSIZENES(ENABLE_NES_MASTER ? nes_hsize : 3'b010),
    .HBURSTNES(ENABLE_NES_MASTER ? nes_hburst : 3'b000),
    .HPROTNES(ENABLE_NES_MASTER ? nes_hprot : 4'b0011),
    .HWDATANES(ENABLE_NES_MASTER ? nes_hwdata : 32'b0),
    .HMASTLOCKNES(ENABLE_NES_MASTER ? nes_hmastlock : 1'b0),
    .HAUSERNES(32'b0),
    .HWUSERNES(ENABLE_NES_MASTER ? {28'b0, nes_hwstrb} : 32'b0),

    .HRDATA_PRG_RAM(target_rdata_node[0]), .HREADYOUT_PRG_RAM(target_ready_out_node[0]), .HRESP_PRG_RAM(target_resp_node[0]), .HRUSER_PRG_RAM(32'b0),
    .HRDATA_GRAPHIC_RAM(target_rdata_node[1]), .HREADYOUT_GRAPHIC_RAM(target_ready_out_node[1]), .HRESP_GRAPHIC_RAM(target_resp_node[1]), .HRUSER_GRAPHIC_RAM(32'b0),
    .HRDATA_APB(target_rdata_node[2]), .HREADYOUT_APB(target_ready_out_node[2]), .HRESP_APB(target_resp_node[2]), .HRUSER_APB(32'b0),
    .HRDATA_NES_RAM(target_rdata_node[3]), .HREADYOUT_NES_RAM(target_ready_out_node[3]), .HRESP_NES_RAM(target_resp_node[3]), .HRUSER_NES_RAM(32'b0),
    .HRDATA_SDCARD(target_rdata_node[4]), .HREADYOUT_SDCARD(target_ready_out_node[4]), .HRESP_SDCARD(target_resp_node[4]), .HRUSER_SDCARD(32'b0),
    .HRDATA_ETHERNET(target_rdata_node[5]), .HREADYOUT_ETHERNET(target_ready_out_node[5]), .HRESP_ETHERNET(target_resp_node[5]), .HRUSER_ETHERNET(32'b0),
    .SCANENABLE(1'b0), .SCANINHCLK(1'b0), .SCANOUTHCLK(),

    .HSEL_PRG_RAM(target_sel_node[0]), .HADDR_PRG_RAM(target_addr_node[0]), .HTRANS_PRG_RAM(target_trans_node[0]), .HWRITE_PRG_RAM(target_write_node[0]), .HSIZE_PRG_RAM(target_size_node[0]), .HBURST_PRG_RAM(target_burst_node[0]), .HPROT_PRG_RAM(target_prot_node[0]), .HWDATA_PRG_RAM(target_wdata_node[0]), .HMASTLOCK_PRG_RAM(), .HREADYMUX_PRG_RAM(target_ready_mux_node[0]), .HAUSER_PRG_RAM(), .HWUSER_PRG_RAM(target_wuser_node[0]),
    .HSEL_GRAPHIC_RAM(target_sel_node[1]), .HADDR_GRAPHIC_RAM(target_addr_node[1]), .HTRANS_GRAPHIC_RAM(target_trans_node[1]), .HWRITE_GRAPHIC_RAM(target_write_node[1]), .HSIZE_GRAPHIC_RAM(target_size_node[1]), .HBURST_GRAPHIC_RAM(target_burst_node[1]), .HPROT_GRAPHIC_RAM(target_prot_node[1]), .HWDATA_GRAPHIC_RAM(target_wdata_node[1]), .HMASTLOCK_GRAPHIC_RAM(), .HREADYMUX_GRAPHIC_RAM(target_ready_mux_node[1]), .HAUSER_GRAPHIC_RAM(), .HWUSER_GRAPHIC_RAM(target_wuser_node[1]),
    .HSEL_APB(target_sel_node[2]), .HADDR_APB(target_addr_node[2]), .HTRANS_APB(target_trans_node[2]), .HWRITE_APB(target_write_node[2]), .HSIZE_APB(target_size_node[2]), .HBURST_APB(target_burst_node[2]), .HPROT_APB(target_prot_node[2]), .HWDATA_APB(target_wdata_node[2]), .HMASTLOCK_APB(), .HREADYMUX_APB(target_ready_mux_node[2]), .HAUSER_APB(), .HWUSER_APB(target_wuser_node[2]),
    .HSEL_NES_RAM(target_sel_node[3]), .HADDR_NES_RAM(target_addr_node[3]), .HTRANS_NES_RAM(target_trans_node[3]), .HWRITE_NES_RAM(target_write_node[3]), .HSIZE_NES_RAM(target_size_node[3]), .HBURST_NES_RAM(target_burst_node[3]), .HPROT_NES_RAM(target_prot_node[3]), .HWDATA_NES_RAM(target_wdata_node[3]), .HMASTLOCK_NES_RAM(), .HREADYMUX_NES_RAM(target_ready_mux_node[3]), .HAUSER_NES_RAM(), .HWUSER_NES_RAM(target_wuser_node[3]),
    .HSEL_SDCARD(target_sel_node[4]), .HADDR_SDCARD(target_addr_node[4]), .HTRANS_SDCARD(target_trans_node[4]), .HWRITE_SDCARD(target_write_node[4]), .HSIZE_SDCARD(target_size_node[4]), .HBURST_SDCARD(target_burst_node[4]), .HPROT_SDCARD(target_prot_node[4]), .HWDATA_SDCARD(target_wdata_node[4]), .HMASTLOCK_SDCARD(), .HREADYMUX_SDCARD(target_ready_mux_node[4]), .HAUSER_SDCARD(), .HWUSER_SDCARD(target_wuser_node[4]),
    .HSEL_ETHERNET(target_sel_node[5]), .HADDR_ETHERNET(target_addr_node[5]), .HTRANS_ETHERNET(target_trans_node[5]), .HWRITE_ETHERNET(target_write_node[5]), .HSIZE_ETHERNET(target_size_node[5]), .HBURST_ETHERNET(target_burst_node[5]), .HPROT_ETHERNET(target_prot_node[5]), .HWDATA_ETHERNET(target_wdata_node[5]), .HMASTLOCK_ETHERNET(), .HREADYMUX_ETHERNET(target_ready_mux_node[5]), .HAUSER_ETHERNET(), .HWUSER_ETHERNET(target_wuser_node[5]),

    .HRDATACPU(cpu_hrdata), .HREADYCPU(cpu_hready), .HRESPCPU(cpu_hresp), .HRUSERCPU(),
    .HRDATANES(nes_hrdata), .HREADYNES(nes_hready), .HRESPNES(nes_hresp), .HRUSERNES()
  );

  // CPU accesses to 0x8000_0000..0x8000_BFFF are intercepted before the CDC
  // bridge.  Keeping an ERROR target here catches accidental slow-domain or
  // NES-master accesses instead of creating an unsafe path into the fast RAM.
  rv32_ahb_error_target slow_main_guard_u (
    .clk(clk), .reset_n(reset_n), .hsel(target_sel_node[0]),
    .htrans(target_trans_node[0]), .hready(target_ready_mux_node[0]),
    .hrdata(target_rdata_node[0]), .hreadyout(target_ready_out_node[0]),
    .hresp(target_resp_node[0]));

  // The shared RAM adapter serializes byte-cell accesses. Both masters reach
  // it through the matrix, so response ownership and wait states stay intact.
  nes_ram_ahb32_adapter shared_ram_u (
    .HCLK(clk), .HRESETn(reset_n), .HSEL(target_sel_node[3]),
    .HADDR(target_addr_node[3]), .HWDATA(target_wdata_node[3]),
    .HSTRB(target_wuser_node[3][3:0]),
    .HWRITE(target_write_node[3]), .HTRANS(target_trans_node[3]),
    .HSIZE(target_size_node[3]), .HREADY(target_ready_mux_node[3]),
    .HRDATA(target_rdata_node[3]), .HREADYOUT(target_ready_out_node[3]),
    .HRESP(target_resp_node[3]));

  // APB target 0/1 are the board Control_Reg and USART. Targets 2/3/4 retain
  // the GPIO, CLINT and PLIC blocks. Interrupt requests leave
  // the APB island on dedicated wires; they are not transported on AHB/APB.
  wire [15:0] apb_select_node;
  wire [31:0] apb_addr_node, apb_wdata_node;
  wire apb_enable_node, apb_write_node;
  wire [3:0] apb_strb_node;
  wire [2:0] apb_prot_node;
  wire apb_clk_node, apb_reset_n_node;
  wire [31:0] apb_rdata_node [0:4];
  wire [4:0] apb_ready_node;
  wire uart_tx_int_node, uart_rx_int_node, gpio_int_node;
  wire [7:0] uart_controller_data_node;
  wire uart_controller_valid_node;
  wire [7:0] serial_joypad_p1_node;
  wire [7:0] serial_joypad_p2_node;
  wire [7:0] diagnostic_led_node;
  APB_Bridge apb_bridge_u (
    .HCLK(clk), .HRESETn(reset_n), .HSELS(target_sel_node[2]),
    .HADDRS(target_addr_node[2]), .HTRANS(target_trans_node[2]),
    .HSIZES(target_size_node[2]), .HWRITES(target_write_node[2]),
    .HREADYS(target_ready_mux_node[2]), .HWDATAS(target_wdata_node[2]),
    .HPROTS(target_prot_node[2]), .HREADYOUTS(target_ready_out_node[2]),
    .HRESPS(target_resp_node[2]), .HRDATAS(target_rdata_node[2]),
    .PCLK(apb_clk_node), .PRESETn(apb_reset_n_node), .PADDR(apb_addr_node), .PENABLE(apb_enable_node),
    .PWRITE(apb_write_node), .PSTRB(apb_strb_node), .PPROT(apb_prot_node),
    .PWDATA(apb_wdata_node), .APBACTIVE(),
    .PSEL0(apb_select_node[0]), .PREADY0(apb_ready_node[0]), .PRDATA0(apb_rdata_node[0]), .PSLVERR0(1'b0),
    .PSEL1(apb_select_node[1]), .PREADY1(apb_ready_node[1]), .PRDATA1(apb_rdata_node[1]), .PSLVERR1(1'b0),
    .PSEL2(apb_select_node[2]), .PREADY2(apb_ready_node[2]), .PRDATA2(apb_rdata_node[2]), .PSLVERR2(1'b0),
    .PSEL3(apb_select_node[3]), .PREADY3(apb_ready_node[3]), .PRDATA3(apb_rdata_node[3]), .PSLVERR3(1'b0),
    .PSEL4(apb_select_node[4]), .PREADY4(apb_ready_node[4]), .PRDATA4(apb_rdata_node[4]), .PSLVERR4(1'b0),
    .PSEL5(apb_select_node[5]), .PREADY5(1'b1), .PRDATA5(32'b0), .PSLVERR5(1'b1),
    .PSEL6(apb_select_node[6]), .PREADY6(1'b1), .PRDATA6(32'b0), .PSLVERR6(1'b1),
    .PSEL7(apb_select_node[7]), .PREADY7(1'b1), .PRDATA7(32'b0), .PSLVERR7(1'b1),
    .PSEL8(apb_select_node[8]), .PREADY8(1'b1), .PRDATA8(32'b0), .PSLVERR8(1'b1),
    .PSEL9(apb_select_node[9]), .PREADY9(1'b1), .PRDATA9(32'b0), .PSLVERR9(1'b1),
    .PSEL10(apb_select_node[10]), .PREADY10(1'b1), .PRDATA10(32'b0), .PSLVERR10(1'b1),
    .PSEL11(apb_select_node[11]), .PREADY11(1'b1), .PRDATA11(32'b0), .PSLVERR11(1'b1),
    .PSEL12(apb_select_node[12]), .PREADY12(1'b1), .PRDATA12(32'b0), .PSLVERR12(1'b1),
    .PSEL13(apb_select_node[13]), .PREADY13(1'b1), .PRDATA13(32'b0), .PSLVERR13(1'b1),
    .PSEL14(apb_select_node[14]), .PREADY14(1'b1), .PRDATA14(32'b0), .PSLVERR14(1'b1),
    .PSEL15(apb_select_node[15]), .PREADY15(1'b1), .PRDATA15(32'b0), .PSLVERR15(1'b1));

  Control_Reg control_regs_u (
    .PCLK(apb_clk_node), .PRESETn(apb_reset_n_node), .PSEL(apb_select_node[0]),
    .PENABLE(apb_enable_node), .PADDR(apb_addr_node), .PWDATA(apb_wdata_node),
    .PRDATA(apb_rdata_node[0]), .PWRITE(apb_write_node), .PREADY(apb_ready_node[0]),
    .PSTRB(apb_strb_node), .PSLVERR(), .serial_buttons(serial_joypads),
    .warm_boot(warm_boot),
    .btn1(board_buttons_n[0]), .btn2(board_buttons_n[1]),
    .btn3(board_buttons_n[2]), .status_flags(status_flags),
    .nes_flags(nes_flags), .joypad_buttons(joypad_buttons),
    .diagnostic_led(diagnostic_led_node), .game_mode(game_mode));

  USART_APB board_uart_u (
    .PCLK(apb_clk_node), .PRESETn(apb_reset_n_node), .PSEL(apb_select_node[1]),
    .PENABLE(apb_enable_node), .PADDR(apb_addr_node), .PWRITE(apb_write_node),
    .PWDATA(apb_wdata_node), .PRDATA(apb_rdata_node[1]), .PREADY(apb_ready_node[1]),
    .PSTRB(apb_strb_node), .PSLVERR(), .RX(uart_rx), .TX(uart_tx),
    .TX_int(uart_tx_int_node), .controller_data(uart_controller_data_node),
    .controller_valid(uart_controller_valid_node), .RX_int(uart_rx_int_node));

  Joypad_Input #(
    .CLK_HZ(SYSTEM_CLOCK_100MHZ ? 100_000_000 : 42_884_160)
  ) serial_joypads_u (
    .clk(apb_clk_node), .rst_n(apb_reset_n_node),
    .rx_data(uart_controller_data_node),
    .rx_valid(uart_controller_valid_node & game_mode), .enable(game_mode),
    .p1(serial_joypad_p1_node), .p2(serial_joypad_p2_node));

  assign serial_joypads = {serial_joypad_p2_node, serial_joypad_p1_node};
  // Before the NES handoff, the visible LEDs exercise the real APB GPIO
  // output-value and output-enable registers.  Game mode restores the donor
  // behavior: one LED per player-1 UART joypad bit.
  assign combined_led = game_mode ? serial_joypad_p1_node :
                             (gpioout[7:0] & gpioen[7:0]);

  gpio_apb gpio_u (
    .pclk_link(apb_clk_node), .prese_tn_link(apb_reset_n_node),
    .psel_link(apb_select_node[2]), .paddr_link(apb_addr_node[7:0]),
    .pwdata_link(apb_wdata_node), .pstrb_link(apb_strb_node),
    .pwrite_link(apb_write_node), .penable_link(apb_enable_node),
    .prdata_link(apb_rdata_node[2]), .pready_link(apb_ready_node[2]),
    .iof0_link(32'b0), .iof1_link(32'b0), .gpioin_link(gpioin),
    .gpioout_link(gpioout), .gpioen_link(gpioen),
    .gpio_intr_link(gpio_int_node));

  clint_apb clint_u (
    .pclk_link(apb_clk_node), .prese_tn_link(apb_reset_n_node),
    .psel_link(apb_select_node[3]), .paddr_link(apb_addr_node[15:0]),
    .pwdata_link(apb_wdata_node), .pstrb_link(apb_strb_node),
    .pwrite_link(apb_write_node), .penable_link(apb_enable_node),
    .prdata_link(apb_rdata_node[3]), .pready_link(apb_ready_node[3]),
    .mtime_link(mtime_clint), .m_timer_int_link(m_timer_int),
    .m_sw_int_link(m_sw_int));

  plic_apb plic_u (
    .pclk_link(apb_clk_node), .prese_tn_link(apb_reset_n_node),
    .psel_link(apb_select_node[4]), .paddr_link(apb_addr_node[27:0]),
    .pwdata_link(apb_wdata_node), .pstrb_link(apb_strb_node),
    .pwrite_link(apb_write_node), .penable_link(apb_enable_node),
    .prdata_link(apb_rdata_node[4]), .pready_link(apb_ready_node[4]),
    .uart_intr_link(uart_tx_int_node | uart_rx_int_node),
    .gpio_intr_link(gpio_int_node), .m_ext_int_link(m_ext_int));

  Display_Controller display_u (
    .clk(clk), .rst_n(reset_n), .hdmi_init_over(hdmi_init),
    .video_test(video_test), .frame_ready(), .video_trace(video_trace),
    .diagnostic_mode((board_buttons_n==3'b000)?2'd3:
      (!board_buttons_n[0] && !board_buttons_n[1])?2'd1:
      (!board_buttons_n[0] && !board_buttons_n[2])?2'd2:2'd0),
    .status_reg(status_flags), .cycle(nes_cycle),
    .scanline(nes_scanline), .color(nes_color),
    .HSEL(target_sel_node[1]), .HADDR(target_addr_node[1]),
    .HWDATA(target_wdata_node[1]), .HWRITE(target_write_node[1]),
    .HTRANS(target_trans_node[1]), .HSIZE(target_size_node[1]),
    .HREADY(target_ready_mux_node[1]), .HRDATA(target_rdata_node[1]),
    .HREADYOUT(target_ready_out_node[1]), .HRESP(target_resp_node[1]),
    .hdmi_clk(hdmi_clk), .PIX_CLK(hdmi_pclk), .VSYNC_o(hdmi_vs),
    .HSYNC_o(hdmi_hs), .DATAENABLE_o(hdmi_de),
    .RED_o(hdmi_data[23:16]), .GREEN_o(hdmi_data[15:8]),
    .BLUE_o(hdmi_data[7:0]));

  wire sd_init_node, sd_busy_node;
  SDCARD_Controller #(.SYSTEM_CLOCK_100MHZ(SYSTEM_CLOCK_100MHZ)) sdcard_u (
    .HCLK(clk), .HRESETn(reset_n), .HSEL(target_sel_node[4]),
    .HADDR(target_addr_node[4]), .HWDATA(target_wdata_node[4]),
    .HWRITE(target_write_node[4]), .HTRANS(target_trans_node[4]),
    .HSIZE(target_size_node[4]), .HREADY(target_ready_mux_node[4]),
    .HRDATA(target_rdata_node[4]), .HREADYOUT(target_ready_out_node[4]),
    .HRESP(target_resp_node[4]), .init_end(sd_init_node), .sd_rd_busy(sd_busy_node),
    .CLK(sd_clk), .MOSI(sd_cmd), .MISO(sd_data0), .CS_N(sd_data3));

  assign target_rdata_node[5] = 32'b0;
  assign target_ready_out_node[5] = 1'b1;
  assign target_resp_node[5] = 1'b0;
  wire [15:0] unused_external_serial_buttons = serial_buttons;
endmodule
