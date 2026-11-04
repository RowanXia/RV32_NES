// Wraps an FPGA block RAM for a 32-bit simple-dual-port memory.
// Maps byte enables and registered read timing to the memory primitive.


`include "config.vh"
`ifndef QUESTA_WINDOWS
  `ifndef CFG_PANGO_DRM_PRIMITIVES
    `define CFG_PANGO_DRM_PRIMITIVES
  `endif
`endif

module pango_drm18k_512x32_sdp #(parameter INIT_FILE = "NONE") (
  input wire clk,  // Clock used for synchronous state updates.
  input wire rd_ce,  // Destination integer-register index.
  input wire [8:0] rd_addr,  // Destination integer-register index.
  output wire [31:0] rd_data,  // Destination integer-register index.
  input wire wr_ce,  // Write-cycle enable qualifier.
  input wire [8:0] wr_addr,  // Address operand or target address selection.
  input wire [31:0] wr_data,  // Data written when the write control is asserted.
  input wire [3:0] wr_strb,  // Provides wr strb for this module.
  input wire wr_en  // Write-enable qualifier.
);
  wire [31:0] memory_rd_data_node;
  reg [31:0] collision_data_q_node;
  wire collision_node;
  wire physical_rd_ce_node;
  reg collision_bypass_q_node;
  integer      merge_byte_node;

  assign collision_node = rd_ce & wr_ce & wr_en & (rd_addr == wr_addr);
  assign physical_rd_ce_node = rd_ce & ~collision_node;

  
  // Update registered memory and request state on the clock edge.
  // Clock the collision_bypass_q, collision_bypass_q state under the specified reset and enable conditions.
  always @(posedge clk) begin
    if (collision_node) begin
      collision_bypass_q_node <= 1'b1;
      // Apply the same combinational operation to each configured element.
      for (merge_byte_node = 0; merge_byte_node < 4; merge_byte_node = merge_byte_node + 1)
        collision_data_q_node[8*merge_byte_node +: 8] <= wr_strb[merge_byte_node] ?
          wr_data[8*merge_byte_node +: 8] : rd_data[8*merge_byte_node +: 8];
    end else if (physical_rd_ce_node) begin
      collision_bypass_q_node <= 1'b0;
    end
  end

  assign rd_data = collision_bypass_q_node ? collision_data_q_node : memory_rd_data_node;

`ifdef CFG_PANGO_DRM_PRIMITIVES
  wire [17:0] doa_node;
  wire [17:0] dob_node;

  GTP_DRM18K_E1 #(
    .GRS_EN("FALSE"),
    .DATA_WIDTH_A(32), .DATA_WIDTH_B(32),
    .WRITE_MODE_A("NORMAL_WRITE"), .WRITE_MODE_B("NORMAL_WRITE"),
    .DOA_REG(0), .DOB_REG(0),
    .RST_TYPE("SYNC"),
    .RAM_MODE("SIMPLE_DUAL_PORT"),
    .INIT_FILE(INIT_FILE),
    .RAM_ADDR_WIDTH(9), .RAM_DATA_WIDTH(32),
    .INIT_FORMAT("HEX")
  ) drm18k (
    .DOA(doa_node), .DOB(dob_node),
    .ADDRA({wr_addr, 5'b0}), .ADDRB({rd_addr, 5'b0}),
    .ADDRA_HOLD(1'b0), .ADDRB_HOLD(1'b0),
    .BWEA(wr_strb), .BWEB(2'b00),
    .DIA({1'b0, wr_data[15:8], 1'b0, wr_data[7:0]}),
    .DIB({1'b0, wr_data[31:24], 1'b0, wr_data[23:16]}),
    .WEA(wr_en), .WEB(1'b0),
    .CLKA(clk), .CLKB(clk), .CEA(wr_ce), .CEB(physical_rd_ce_node),
    .ORCEA(1'b1), .ORCEB(1'b1),
    .RSTA(1'b0), .RSTB(1'b0)
  );

  assign memory_rd_data_node = {dob_node[16:9], dob_node[7:0], doa_node[16:9], doa_node[7:0]};
`else
  reg [31:0] ram_node [0:511];
  reg [8:0] rd_addr_q_node;
  integer byte_index_node;

  initial if (INIT_FILE != "NONE") $readmemh(INIT_FILE, ram_node);

  // Updates sequential state on the specified clock event.
  // Clock the rd_addr_q state under the specified reset and enable conditions.
  always @(posedge clk) begin
    if (physical_rd_ce_node) rd_addr_q_node <= rd_addr;
    if (wr_ce && wr_en)
      // Apply the same combinational operation to each configured element.
      for (byte_index_node = 0; byte_index_node < 4; byte_index_node = byte_index_node + 1)
        if (wr_strb[byte_index_node])
          ram_node[wr_addr][8*byte_index_node +: 8] <= wr_data[8*byte_index_node +: 8];
  end

  assign memory_rd_data_node = ram_node[rd_addr_q_node];
`endif
endmodule
