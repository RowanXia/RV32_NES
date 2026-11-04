module PaletteRam(
	input clk,
	input ce,
	input reset,
	input [4:0] addr,
	input [5:0] din,
	output [5:0] dout,
	input write
);
  reg [5:0] palette [0:31];
  // Force read from backdrop channel if reading from any addr 0.
  wire [4:0] addr2 = (addr[1:0] == 0) ? 0 : addr;
  assign dout = palette[addr2];
  always @(posedge clk)
  if (reset) begin
    palette[0] <= 6'h0F;
    palette[1] <= 6'h2C;
    palette[2] <= 6'h10;
    palette[3] <= 6'h1C;
    palette[4] <= 6'h0F;
    palette[5] <= 6'h37;
    palette[6] <= 6'h27;
    palette[7] <= 6'h07;
    palette[8] <= 6'h0F;
    palette[9] <= 6'h28;
    palette[10] <= 6'h16;
    palette[11] <= 6'h07;
    palette[12] <= 6'h0F;
    palette[13] <= 6'h28;
    palette[14] <= 6'h0F;
    palette[15] <= 6'h2C;
    palette[16] <= 6'h0F;
    palette[17] <= 6'h0F;
    palette[18] <= 6'h2C;
    palette[19] <= 6'h11;
    palette[20] <= 6'h0F;
    palette[21] <= 6'h0F;
    palette[22] <= 6'h20;
    palette[23] <= 6'h38;
    palette[24] <= 6'h0F;
    palette[25] <= 6'h0F;
    palette[26] <= 6'h15;
    palette[27] <= 6'h27;
    palette[28] <= 6'h0F;
    palette[29] <= 6'h0F;
    palette[30] <= 6'h11;
    palette[31] <= 6'h3C;
  end else if (ce && write) begin
    // Allow writing only to x0
    if (!(addr[3:2] != 0 && addr[1:0] == 0))
      palette[addr2] <= din;
  end
endmodule  // PaletteRam