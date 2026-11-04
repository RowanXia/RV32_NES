// Module role: Exposes a 48-KiB AHB main-memory window through initialized data banks.
// Behavioral interface: AHB write strobes and read responses select the addressed word and byte lanes.

`include "../config.vh"

module ram_ahb  #(
  parameter [31:0] BASE = `CFG_UNCORE_RAM_BASE
) (
  input wire hclk,
  input wire hrese_tn, input wire hsel_ram,
  input wire [31:0] haddr, input wire hwrite,
  input wire hready,
  input wire [1:0] htrans, input wire [31:0] hwdata,
  input wire [3:0] hwstrb,
  output reg [31:0] hread_ram,
  output wire hresp_ram,
  output wire hready_ram
);
  localparam integer banks_node = 6;
  localparam [31:0] limit_node = BASE + `CFG_UNCORE_RAM_BYTES;
  wire accept_node;
  wire address_valid_node;
  wire [13:0] word_offset_node;
  wire [2:0] address_bank_node;
  reg [2:0] bank_d_node;
  wire [10:0] address_word_node;
  reg [10:0] word_d_node;
  reg write_d_node;
  localparam [1:0] err_idle_node = 2'd0;
  localparam [1:0] err_first_node = 2'd1;
  localparam [1:0] err_second_node = 2'd2;
  reg [1:0] error_state_node;
  wire [31:0] bank_rdata_node [0:banks_node-1];
  reg [banks_node-1:0] bank_we_node;

`ifdef CFG_BOARD_APP_PRIMITIVE_INIT
  localparam bank0_init_node = "software/board_app/init/bank0.mem";
  localparam bank1_init_node = "software/board_app/init/bank1.mem";
  localparam bank2_init_node = "software/board_app/init/bank2.mem";
  localparam bank3_init_node = "software/board_app/init/bank3.mem";
  localparam bank4_init_node = "software/board_app/init/bank4.mem";
  localparam bank5_init_node = "software/board_app/init/bank5.mem";
`elsif CFG_INTERRUPT_TEST_PRIMITIVE_INIT
  localparam bank0_init_node = "verification/peripherals/init/bank0.mem";
  localparam bank1_init_node = "verification/peripherals/init/bank1.mem";
  localparam bank2_init_node = "verification/peripherals/init/bank2.mem";
  localparam bank3_init_node = "verification/peripherals/init/bank3.mem";
  localparam bank4_init_node = "verification/peripherals/init/bank4.mem";
  localparam bank5_init_node = "verification/peripherals/init/bank5.mem";
`elsif CFG_BOUNDARY_TEST_PRIMITIVE_INIT
  localparam bank0_init_node = "verification/boundary/init/bank0.mem";
  localparam bank1_init_node = "verification/boundary/init/bank1.mem";
  localparam bank2_init_node = "verification/boundary/init/bank2.mem";
  localparam bank3_init_node = "verification/boundary/init/bank3.mem";
  localparam bank4_init_node = "verification/boundary/init/bank4.mem";
  localparam bank5_init_node = "verification/boundary/init/bank5.mem";
`elsif CFG_COREMARK_PRIMITIVE_INIT
  localparam bank0_init_node = "verification/coremark_primitive/init/bank0.mem";
  localparam bank1_init_node = "verification/coremark_primitive/init/bank1.mem";
  localparam bank2_init_node = "verification/coremark_primitive/init/bank2.mem";
  localparam bank3_init_node = "verification/coremark_primitive/init/bank3.mem";
  localparam bank4_init_node = "verification/coremark_primitive/init/bank4.mem";
  localparam bank5_init_node = "verification/coremark_primitive/init/bank5.mem";
`else
  localparam bank0_init_node = "NONE";
  localparam bank1_init_node = "NONE";
  localparam bank2_init_node = "NONE";
  localparam bank3_init_node = "NONE";
  localparam bank4_init_node = "NONE";
  localparam bank5_init_node = "NONE";
`endif

  assign address_valid_node = (haddr >= BASE) & (haddr < limit_node);
  assign word_offset_node   = (haddr - BASE) >> 2;
  assign address_bank_node  = word_offset_node[13:11];
  assign address_word_node  = word_offset_node[10:0];
  assign accept_node        = hready & hsel_ram & htrans[1];

  always @(posedge hclk) begin
    if (!hrese_tn) begin
      write_d_node <= 1'b0;
      bank_d_node <= 1'b0;
      word_d_node <= 1'b0;
    end else if (hready) begin
      write_d_node <= accept_node & hwrite & address_valid_node;
      bank_d_node <= address_bank_node;
      word_d_node <= address_word_node;
    end
  end

  // AHB-Lite ERROR response: first cycle HRESP=1/HREADY=0, second cycle
  // HRESP=1/HREADY=1.  The address was accepted while ERR_IDLE; no invalid
  // write enable is ever generated.
  always @(posedge hclk)
    if (!hrese_tn) error_state_node <= err_idle_node;
    else case (error_state_node)
      err_idle_node:   if (accept_node & ~address_valid_node) error_state_node <= err_first_node;
                  else                         error_state_node <= err_idle_node;
      err_first_node:                               error_state_node <= err_second_node;
      err_second_node:                              error_state_node <= err_idle_node;
      default:                                 error_state_node <= err_idle_node;
    endcase

  always @* begin
    bank_we_node = 1'b0;
    if (write_d_node && bank_d_node < banks_node) bank_we_node[bank_d_node] = 1'b1;
  end

  genvar bank_node;
  for (bank_node = 0; bank_node < banks_node; bank_node = bank_node + 1) begin : memory_bank
    if (bank_node == 0) begin : bank_init
      pango_drm36k_2kx32_tdp #(.INIT_FILE(bank0_init_node)) memory_node (
        .clk(hclk), .ce(hready), .rd_addr(address_word_node), .rd_data(bank_rdata_node[bank_node]),
        .wr_addr(word_d_node), .wr_data(hwdata), .wr_strb(hwstrb), .wr_en(bank_we_node[bank_node]));
    end else if (bank_node == 1) begin : bank_init
      pango_drm36k_2kx32_tdp #(.INIT_FILE(bank1_init_node)) memory_node (
        .clk(hclk), .ce(hready), .rd_addr(address_word_node), .rd_data(bank_rdata_node[bank_node]),
        .wr_addr(word_d_node), .wr_data(hwdata), .wr_strb(hwstrb), .wr_en(bank_we_node[bank_node]));
    end else if (bank_node == 2) begin : bank_init
      pango_drm36k_2kx32_tdp #(.INIT_FILE(bank2_init_node)) memory_node (
        .clk(hclk), .ce(hready), .rd_addr(address_word_node), .rd_data(bank_rdata_node[bank_node]),
        .wr_addr(word_d_node), .wr_data(hwdata), .wr_strb(hwstrb), .wr_en(bank_we_node[bank_node]));
    end else if (bank_node == 3) begin : bank_init
      pango_drm36k_2kx32_tdp #(.INIT_FILE(bank3_init_node)) memory_node (
        .clk(hclk), .ce(hready), .rd_addr(address_word_node), .rd_data(bank_rdata_node[bank_node]),
        .wr_addr(word_d_node), .wr_data(hwdata), .wr_strb(hwstrb), .wr_en(bank_we_node[bank_node]));
    end else if (bank_node == 4) begin : bank_init
      pango_drm36k_2kx32_tdp #(.INIT_FILE(bank4_init_node)) memory_node (
        .clk(hclk), .ce(hready), .rd_addr(address_word_node), .rd_data(bank_rdata_node[bank_node]),
        .wr_addr(word_d_node), .wr_data(hwdata), .wr_strb(hwstrb), .wr_en(bank_we_node[bank_node]));
    end else begin : bank_init
      pango_drm36k_2kx32_tdp #(.INIT_FILE(bank5_init_node)) memory_node (
        .clk(hclk), .ce(hready), .rd_addr(address_word_node), .rd_data(bank_rdata_node[bank_node]),
        .wr_addr(word_d_node), .wr_data(hwdata), .wr_strb(hwstrb), .wr_en(bank_we_node[bank_node]));
    end
  end

  always @* begin
    hread_ram = 1'b0;
    if (bank_d_node < banks_node) hread_ram = bank_rdata_node[bank_d_node];
  end

  assign hready_ram = error_state_node != err_first_node;
  assign hresp_ram  = error_state_node != err_idle_node;

// These hierarchical helpers are simulation-only.  Keeping the guard tied to
// the simulator (rather than to the primitive implementation selected in the
// child module) prevents synthesis from parsing references to a behavioral RAM
// that does not exist in the DRM implementation.
`ifdef QUESTA_WINDOWS
`ifndef CFG_PANGO_DRM_PRIMITIVES
  task automatic sim_write_word(input [31:0] index, input [31:0] data);
    case (index[13:11])
      0: memory_bank[0].bank_init.memory_node.ram_node[index[10:0]] = data;
      1: memory_bank[1].bank_init.memory_node.ram_node[index[10:0]] = data;
      2: memory_bank[2].bank_init.memory_node.ram_node[index[10:0]] = data;
      3: memory_bank[3].bank_init.memory_node.ram_node[index[10:0]] = data;
      4: memory_bank[4].bank_init.memory_node.ram_node[index[10:0]] = data;
      5: memory_bank[5].bank_init.memory_node.ram_node[index[10:0]] = data;
      default: ;
    endcase
  endtask

  function automatic [31:0] sim_read_word(input [31:0] index);
    case (index[13:11])
      0: sim_read_word = memory_bank[0].bank_init.memory_node.ram_node[index[10:0]];
      1: sim_read_word = memory_bank[1].bank_init.memory_node.ram_node[index[10:0]];
      2: sim_read_word = memory_bank[2].bank_init.memory_node.ram_node[index[10:0]];
      3: sim_read_word = memory_bank[3].bank_init.memory_node.ram_node[index[10:0]];
      4: sim_read_word = memory_bank[4].bank_init.memory_node.ram_node[index[10:0]];
      5: sim_read_word = memory_bank[5].bank_init.memory_node.ram_node[index[10:0]];
      default: sim_read_word = 32'bx;
    endcase
  endfunction
`else
  // The full primitive CoreMark build is initialized through each DRM's
  // INIT_FILE.  These compatibility helpers deliberately do not write the
  // vendor model's private storage.
  task automatic sim_write_word(input [31:0] index, input [31:0] data);
    begin
      // Intentionally empty: vendor DRM contents are initialized by INIT_FILE.
    end
  endtask
  function automatic [31:0] sim_read_word(input [31:0] index);
    sim_read_word = 32'bx;
  endfunction
`endif
`endif
endmodule
