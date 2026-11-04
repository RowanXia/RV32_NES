// Modified for RV32 NES integration, 2026-11-01.
// Board entry point for the CPU and application clock domains.
// CFG_CPU_100MHZ selects the 100-MHz CPU PLL; the default CPU rate is 80 MHz.
// The game and peripherals retain their separate 42.8786-MHz clock.
module RV32_NES #(
  parameter SYSTEM_CLOCK_100MHZ = 1'b0
) (
  input  wire CLK_27MHz,
  input  wire RSTN,
  input  wire [4:1] KEY,
  output wire HD_TX_PCLK,
  output wire HD_TX_VS,
  output wire HD_TX_HS,
  output wire HD_TX_DE,
  output wire [23:0] HD_TX_D,
  output wire HD_TX_SC_MC,
  output wire HD_TX_I2S1,
  output wire HD_TX_I2S0,
  output wire HD_TX_WS,
  input  wire HD_TX_INT,
  output wire HD_SCL,
  inout  wire HD_SDA,
  output wire RSTN_OUT,
  input  wire FPGA_UART_RXD,
  output wire FPGA_UART_TXD,
  output wire SD_CLK,
  output wire SD_CMD,
  input  wire SD_DATA0,
  output wire SD_DATA3,
  input  wire SD_SDDEF,
  output wire [7:0] LED
);
  wire cpu_clk_fast, sys_clk_42m88, hdmi_clk_148m5, audio_clk_49m152;
  wire cpu_lock, sys_lock, hdmi_lock, audio_lock;

`ifdef CFG_CPU_100MHZ
  localparam CPU_CLOCK_100MHZ = 1'b1;
`else
  localparam CPU_CLOCK_100MHZ = SYSTEM_CLOCK_100MHZ;
`endif

  PLL_CPU #(.OUTPUT_100MHZ(CPU_CLOCK_100MHZ)) cpu_pll_u(
    .clkout0(cpu_clk_fast), .clkin1(CLK_27MHz), .lock(cpu_lock));
  PLL_42p88MHz #(.OUTPUT_100MHZ(1'b0)) sys_pll_u(
    .clkout0(sys_clk_42m88), .clkin1(CLK_27MHz), .lock(sys_lock));
  PLL_148p5MHz hdmi_pll_u(.clkout0(hdmi_clk_148m5), .clkin1(CLK_27MHz), .lock(hdmi_lock));
  PLL_49p152MHz audio_pll_u(.clkout0(audio_clk_49m152), .clkin1(CLK_27MHz), .lock(audio_lock));

  wire all_locked = cpu_lock & sys_lock & hdmi_lock & audio_lock;
  wire board_reset, board_reset_n;
  Reset_Control #(.CLK_FREQ(42_880_000), .DEBOUNCE_TIME(10)) board_reset_u(
    .clk(sys_clk_42m88), .RST_in(RSTN), .pll_locked(all_locked),
    .rst_out(board_reset), .rst_out_n(board_reset_n));

  wire [4:1] key_clean_n;
  genvar key_index;
  generate
    for (key_index = 1; key_index <= 4; key_index = key_index + 1) begin : key_debounce
      Button_Debounce #(.CLK_FREQ(42_880_000), .DEBOUNCE_TIME(10)) key_u(
        .clk(sys_clk_42m88), .rst_n(board_reset_n),
        .key_in(KEY[key_index]), .key_out(key_clean_n[key_index]));
    end
  endgenerate

  wire hdmi_init_rx, hdmi_init_tx, hdmi_init_done;
  wire audio_config_ok, audio_i2c_nack;
  wire [103:0] audio_debug_regs;
  hdmi_tx_config hdmi_config_u(
    .clk(sys_clk_42m88), .rst_n(board_reset_n),
    .init_over_rx(hdmi_init_rx), .init_over_tx(hdmi_init_tx),
    .iic_scl(HD_SCL), .iic_sda(HD_SDA),
    .audio_config_ok(audio_config_ok), .nack_seen(audio_i2c_nack), .audio_debug_regs(audio_debug_regs));
  assign hdmi_init_done = hdmi_init_rx & hdmi_init_tx;

  wire soc_reset;
  wire [31:0] unused_haddr, unused_hwdata;
  wire [3:0] unused_hwstrb, unused_hprot;
  wire [2:0] unused_hsize, unused_hburst;
  wire [1:0] unused_htrans;
  wire unused_hsel, unused_hwrite, unused_hmastlock, unused_hready;
  // GPIO is software-visible in both applications.  In the CoreMark phase its
  // low byte directly drives the board LEDs; the NES phase keeps its existing
  // diagnostic and joypad indications below.
  wire [31:0] gpio_output, gpio_output_enable;
  wire [15:0] nes_audio_sample;
  wire nes_audio_enable;
  wire [7:0] joypad_led;
  wire recovery_reset_n, boot_retry_used, boot_failed;
  wire game_mode_status, menu_ready;
  wire [7:0] video_trace;
  wire main_uart_txd, audio_uart_txd;
  wire audio_diag_view = !key_clean_n[4] && !key_clean_n[1];
  assign FPGA_UART_TXD = audio_diag_view ? audio_uart_txd : main_uart_txd;
  nes_audio_uart_diag audio_uart(.clk(sys_clk_42m88), .rst_n(recovery_reset_n),
    .enable(audio_diag_view), .regs(audio_debug_regs),
    .flags({6'b0,audio_i2c_nack,hdmi_init_tx}), .tx(audio_uart_txd));
  // Start recovery timing after firmware handoff; reset both SoC domains together.
  rv32_nes_boot_supervisor boot_supervisor_u(
    .clk(sys_clk_42m88), .base_rst_n(board_reset_n),
    .handoff(game_mode_status), .menu_ready(menu_ready),
    .rst_n(recovery_reset_n), .retry_used(boot_retry_used),
    .boot_failed(boot_failed));
  reg game_session_latched;

  // Preserve game handoff across KEY0 reset to return directly to the menu.
  // PLL unlock clears the retained flag for power-up or reconfiguration.
  always @(posedge sys_clk_42m88 or negedge all_locked) begin
    if (!all_locked)
      game_session_latched <= 1'b0;
    else if (game_mode_status)
      game_session_latched <= 1'b1;
  end

  RV32_soc #(
    .ENABLE_NES_MASTER(1'b1),
    .USE_INTERNAL_NES(1'b1),
      // The matrix, APB, SD card and NES logic use sys_clk_42m88, not the
      // fast CPU clock.  Keep their timing constants in the 42.88-MHz mode.
      .SYSTEM_CLOCK_100MHZ(1'b0),
    .DUAL_CLOCK(1'b1)
  ) soc_u (
    .clk(cpu_clk_fast), .peripheral_clk(sys_clk_42m88),
    .reset_ext(~recovery_reset_n), .reset(soc_reset),
    .hrdataext(32'b0), .hreadyext(1'b1), .hrespext(1'b0),
    .hselext(unused_hsel), .external_hold(1'b0),
    .hclk(), .hrese_tn(), .haddr(unused_haddr),
    .hwdata(unused_hwdata), .hwstrb(unused_hwstrb),
    .hwrite(unused_hwrite), .hsize(unused_hsize),
    .hburst(unused_hburst), .hprot(unused_hprot),
    .htrans(unused_htrans), .hmastlock(unused_hmastlock),
    .hready(unused_hready),
    .nes_audio_sample(nes_audio_sample),
    .nes_audio_enable(nes_audio_enable),
    .gpioin(32'b0), .gpioout(gpio_output),
    .gpioen(gpio_output_enable),
    .uart_sin(FPGA_UART_RXD), .UARTSout(main_uart_txd),
    .serial_buttons(16'b0),
    .warm_boot(game_session_latched),
    .game_mode_status(game_mode_status),
    .menu_ready(menu_ready), .video_trace(video_trace), .video_test(~key_clean_n[4]),
    .board_buttons_n({key_clean_n[3],key_clean_n[2],key_clean_n[1]}),
    .hdmi_clk(hdmi_clk_148m5), .hdmi_init(hdmi_init_done),
    .hdmi_pclk(HD_TX_PCLK), .hdmi_vs(HD_TX_VS),
    .hdmi_hs(HD_TX_HS), .hdmi_de(HD_TX_DE), .hdmi_data(HD_TX_D),
    .sd_clk(SD_CLK), .sd_cmd(SD_CMD), .sd_data0(SD_DATA0),
    .sd_data3(SD_DATA3), .joypad_led(joypad_led));

  wire audio_reset_n;
  nes_reset_sync audio_reset_u(.clk(audio_clk_49m152),
    .arst_n(recovery_reset_n), .rst_n(audio_reset_n));
  wire [16:0] audio_bundle;
  nes_cdc_mailbox #(.WIDTH(17)) audio_cdc_u(
    .src_clk(sys_clk_42m88), .src_rst_n(recovery_reset_n),
    .src_data({nes_audio_enable, nes_audio_sample}),
    .dst_clk(audio_clk_49m152), .dst_rst_n(audio_reset_n),
    .dst_data(audio_bundle));
  Audio_Controller audio_u(
    .clk(audio_clk_49m152), .rst_n(audio_reset_n),
    .audio_sample(audio_bundle[16] ? audio_bundle[15:0] : 16'h8000),
    .i2s_tx_ws(HD_TX_WS), .i2s_tx_sc_mc(HD_TX_SC_MC),
    .i2s_tx_data0(HD_TX_I2S0), .i2s_tx_data1(HD_TX_I2S1),
    .i2s_tx_int(HD_TX_INT));

  wire audio_heartbeat,audio_bclk_seen,audio_ws_seen,audio_sd_seen;
  nes_audio_led_diag audio_led_observer(.clk(audio_clk_49m152),.rst_n(audio_reset_n),
    .bclk(HD_TX_SC_MC),.ws(HD_TX_WS),.sd(HD_TX_I2S0),.tone_active(1'b1),
    .heartbeat(audio_heartbeat),.bclk_seen(audio_bclk_seen),.ws_seen(audio_ws_seen),.sd_seen(audio_sd_seen));
  wire [7:0] audio_led_status = {audio_config_ok,audio_i2c_nack,1'b0,audio_sd_seen,audio_ws_seen,audio_bclk_seen,audio_heartbeat,hdmi_init_tx};
  wire [7:0] coremark_led;
  // A GPIO bit only controls its LED after software has enabled that output.
  // software/main.c writes GPIO output_en/output_val during CoreMark progress.
  assign coremark_led = gpio_output[7:0] & gpio_output_enable[7:0];
  assign RSTN_OUT = board_reset_n;
  // Before firmware hands off to the game, LEDs are the software GPIO result.
  // Once NES mode is active, retain the existing audio, boot, video and joypad views.
  assign LED = !game_mode_status ? coremark_led : audio_diag_view ? audio_led_status : (!key_clean_n[4] && !key_clean_n[3]) ?
      {boot_failed,boot_retry_used,4'b0,menu_ready,game_mode_status} : (!key_clean_n[4] ? video_trace : joypad_led);
  wire unused_sd_detect = SD_SDDEF;
endmodule
