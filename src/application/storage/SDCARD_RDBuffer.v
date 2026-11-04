// Store one 512-byte sector in 32 parallel distributed-RAM bit slices.
// Register the read address to preserve the one-HCLK read latency.
// The nine-bit interface requires its two upper address bits to remain zero.
module SDCARD_RDBuffer (
  input  wire [31:0] wr_data,
  input  wire [8:0]  wr_addr,
  input  wire        wr_en,
  input  wire        wr_clk,
  input  wire        wr_rst,
  output wire [31:0] rd_data,
  input  wire [8:0]  rd_addr,
  input  wire        rd_clk,
  input  wire        rd_rst
);
  reg [6:0] rd_addr_q;

  always @(posedge rd_clk or posedge rd_rst) begin
    if (rd_rst)
      rd_addr_q <= 7'b0;
    else
      rd_addr_q <= rd_addr[6:0];
  end

  genvar bit_index;
  generate
    for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin : g_data_bit
      GTP_RAM128X1DP #(.INIT(128'b0)) sector_memory (
        .DO   (rd_data[bit_index]),
        .DI   (wr_data[bit_index]),
        .RADDR(rd_addr_q),
        .WADDR(wr_addr[6:0]),
        .WCLK (wr_clk),
        .WE   (wr_en & ~wr_rst)
      );
    end
  endgenerate

`ifndef SYNTHESIS
  // Report unsupported addresses instead of silently accepting memory aliasing.
  always @(posedge wr_clk)
    if (wr_en && |wr_addr[8:7])
      $error("SDCARD_RDBuffer write address exceeds one-sector LUTRAM: %h", wr_addr);

  always @(posedge rd_clk)
    if (!rd_rst && |rd_addr[8:7])
      $error("SDCARD_RDBuffer read address exceeds one-sector LUTRAM: %h", rd_addr);
`endif
endmodule
