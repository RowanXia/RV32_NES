// Wraps an FPGA block RAM for a wide simple-dual-port array.
// Preserves the memory macro read/write interface.


`include "config.vh"
`ifndef QUESTA_WINDOWS
  `ifndef CFG_PANGO_DRM_PRIMITIVES
    `define CFG_PANGO_DRM_PRIMITIVES
  `endif
`endif

module pango_drm36k_1024x36_sdp (
  input wire clk,  // Clock used for synchronous state updates.
  input wire rd_ce,  // Destination integer-register index.
  input wire [9:0] rd_addr,  // Destination integer-register index.
  output wire [35:0] rd_data,  // Destination integer-register index.
  input wire wr_ce,  // Write-cycle enable qualifier.
  input wire [9:0] wr_addr,  // Address operand or target address selection.
  input wire [35:0] wr_data,  // Data written when the write control is asserted.
  input wire wr_en  // Write-enable qualifier.
);
`ifdef CFG_PANGO_DRM_PRIMITIVES
  wire [35:0] doa_unused_node;
  wire ecc_sbit_unused_node;
  wire ecc_dbit_unused_node;
  wire [8:0] ecc_addr_unused_node;
  wire [7:0] ecc_parity_unused_node;

  GTP_DRM36K_E1 #(
    .GRS_EN("FALSE"), .DATA_WIDTH_A(36), .DATA_WIDTH_B(36),
    .WRITE_MODE_A("NORMAL_WRITE"), .WRITE_MODE_B("NORMAL_WRITE"),
    .DOA_REG(0), .DOB_REG(0), .RST_TYPE("SYNC"),
    .RAM_MODE("SIMPLE_DUAL_PORT"), .RAM_CASCADE("NONE"),
    .ECC_WRITE_EN("FALSE"), .ECC_READ_EN("FALSE"),
    .INIT_FILE("NONE"), .RAM_ADDR_WIDTH(10), .RAM_DATA_WIDTH(36),
    .INIT_FORMAT("HEX")
  ) drm36k (
    .DOA(doa_unused_node), .DOB(rd_data),
    .DIA(wr_data), .DIB(36'b0),
    .ADDRA({1'b1, wr_addr, 5'b0}), .ADDRB({1'b1, rd_addr, 5'b0}),
    .ADDRA_HOLD(1'b0), .ADDRB_HOLD(1'b0),
    .CSA(3'b000), .CSB(3'b000), .BWEA(8'hff), .BWEB(4'b0000),
    .CLKA(clk), .CLKB(clk), .CEA(wr_ce), .CEB(rd_ce),
    .WEA(wr_en), .WEB(1'b0), .ORCEA(1'b1), .ORCEB(1'b1),
    .RSTA(1'b0), .RSTB(1'b0), .CINA(1'b0), .CINB(1'b0),
    .COUTA(), .COUTB(), .INJECT_SBITERR(1'b0), .INJECT_DBITERR(1'b0),
    .ECC_SBITERR(ecc_sbit_unused_node), .ECC_DBITERR(ecc_dbit_unused_node),
    .ECC_RDADDR(ecc_addr_unused_node), .ECC_PARITY(ecc_parity_unused_node)
  );
`else
  reg [35:0] ram_node [0:1023];

  
  function [36-1:0] RAM_two_state;
    input [36-1:0] value;  // Integer argument used to calculate the local logarithm.
    integer n_node;
    begin
      // Apply the same combinational operation to each configured element.
      for (n_node = 0; n_node < 36; n_node = n_node + 1)
        RAM_two_state[n_node] = (value[n_node] === 1'b1);
    end
  endfunction
  wire [36-1:0] ram_write_clean_node;
  assign ram_write_clean_node = RAM_two_state(wr_data);
  
  integer init_ram_index_node;
  initial begin
    // Apply the same combinational operation to each configured element.
    for (init_ram_index_node = 0; init_ram_index_node <= (1023); init_ram_index_node = init_ram_index_node + 1)
      ram_node[init_ram_index_node] = {(35)+1{1'b0}};
  end

  reg [9:0] rd_addr_q_node;
  // Update registered memory and request state on the clock edge.
  // Clock the rd_addr_q state under the specified reset and enable conditions.
  always @(posedge clk) begin
    if (rd_ce) rd_addr_q_node <= rd_addr;
    if (wr_ce && wr_en) ram_node[wr_addr] <= ram_write_clean_node;
  end
  assign rd_data = RAM_two_state(ram_node[rd_addr_q_node]);
`endif
endmodule
