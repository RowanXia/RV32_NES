// Wraps an FPGA block RAM as a true-dual-port data array.
// Connects independent port addresses, enables, and data.


`include "config.vh"
`ifndef QUESTA_WINDOWS
  `ifndef CFG_PANGO_DRM_PRIMITIVES
    `define CFG_PANGO_DRM_PRIMITIVES
  `endif
`endif

module pango_drm36k_2kx32_tdp #(parameter INIT_FILE = "NONE") (
  input wire clk,  // Clock used for synchronous state updates.
  input wire ce,  // Provides ce for this module.
  input wire [10:0] rd_addr,  // Destination integer-register index.
  output wire [31:0] rd_data,  // Destination integer-register index.
  input wire [10:0] wr_addr,  // Address operand or target address selection.
  input wire [31:0] wr_data,  // Data written when the write control is asserted.
  input wire [3:0] wr_strb,  // Provides wr strb for this module.
  input wire wr_en  // Write-enable qualifier.
);
`ifdef CFG_PANGO_DRM_PRIMITIVES
  wire [35:0] dob_lo_node;
  wire [35:0] dob_hi_node;

  genvar slice_node;
    // Apply the same combinational operation to each configured element.
    for (slice_node = 0; slice_node < 2; slice_node = slice_node + 1) begin : drm_slice
    wire [35:0] doa_unused_node;
    wire [35:0] dob_slice_node;
    wire [35:0] dia_node;
    wire [7:0] bwea_node;
    wire ecc_sbit_unused_node;
  wire ecc_dbit_unused_node;
    wire [8:0] ecc_addr_unused_node;
    wire [7:0] ecc_parity_unused_node;

    if (slice_node == 0) begin : low_half
      assign dia_node = {19'b0, wr_data[15:8], 1'b0, wr_data[7:0]};
      assign bwea_node = {6'b0, wr_strb[1:0]};
      assign dob_lo_node = dob_slice_node;
    end else begin : high_half
      assign dia_node = {19'b0, wr_data[31:24], 1'b0, wr_data[23:16]};
      assign bwea_node = {6'b0, wr_strb[3:2]};
      assign dob_hi_node = dob_slice_node;
    end

    GTP_DRM36K_E1 #(
      .GRS_EN("FALSE"), .DATA_WIDTH_A(16), .DATA_WIDTH_B(16),
      .WRITE_MODE_A("NORMAL_WRITE"), .WRITE_MODE_B("NORMAL_WRITE"),
      .DOA_REG(0), .DOB_REG(0), .RST_TYPE("SYNC"),
      .RAM_MODE("TRUE_DUAL_PORT"), .RAM_CASCADE("NONE"),
      .ECC_WRITE_EN("FALSE"), .ECC_READ_EN("FALSE"),
      
      
      .INIT_FILE(INIT_FILE), .BLOCK_X(slice_node), .BLOCK_Y(0),
      .RAM_ADDR_WIDTH(11), .RAM_DATA_WIDTH(32),
      .INIT_FORMAT("HEX")
    ) drm36k (
      .DOA(doa_unused_node), .DOB(dob_slice_node),
      .DIA(dia_node), .DIB(36'b0),
      .ADDRA({1'b1, wr_addr, 4'b0}), .ADDRB({1'b1, rd_addr, 4'b0}),
      .ADDRA_HOLD(1'b0), .ADDRB_HOLD(1'b0),
      .CSA(3'b000), .CSB(3'b000), .BWEA(bwea_node), .BWEB(4'b0000),
      .CLKA(clk), .CLKB(clk), .CEA(ce), .CEB(ce),
      .WEA(wr_en), .WEB(1'b0), .ORCEA(1'b1), .ORCEB(1'b1),
      .RSTA(1'b0), .RSTB(1'b0), .CINA(1'b0), .CINB(1'b0),
      .COUTA(), .COUTB(), .INJECT_SBITERR(1'b0), .INJECT_DBITERR(1'b0),
      .ECC_SBITERR(ecc_sbit_unused_node), .ECC_DBITERR(ecc_dbit_unused_node),
      .ECC_RDADDR(ecc_addr_unused_node), .ECC_PARITY(ecc_parity_unused_node)
    );
  end

  assign rd_data = {dob_hi_node[16:9], dob_hi_node[7:0], dob_lo_node[16:9], dob_lo_node[7:0]};
`else
  reg [31:0] ram_node [0:2047];
  reg [10:0] rd_addr_q_node;
  integer byte_index_node;
  initial if (INIT_FILE != "NONE") $readmemh(INIT_FILE, ram_node);
  // Update registered memory and request state on the clock edge.
  // Clock the rd_addr_q state under the specified reset and enable conditions.
  always @(posedge clk) begin
    if (ce) rd_addr_q_node <= rd_addr;
    if (ce && wr_en)
      // Apply the same combinational operation to each configured element.
      for (byte_index_node = 0; byte_index_node < 4; byte_index_node = byte_index_node + 1)
        if (wr_strb[byte_index_node])
          ram_node[wr_addr][8*byte_index_node +: 8] <= wr_data[8*byte_index_node +: 8];
  end
  assign rd_data = ram_node[rd_addr_q_node];
`endif
endmodule
