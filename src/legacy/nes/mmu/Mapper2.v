// mapper2. PRG ROM: 128kB. Bank Size: 16kB.
module Mapper2(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [18:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input chr_read, input [13:0] chr_ain, output [18:0] chr_aout,
            output chr_allow,                      // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.

// CPU $8000-$BFFF: 16 KB switchable PRG ROM bank
// CPU $C000-$FFFF: 16 KB PRG ROM bank, fixed to the last bank


// PRG ROM bank 选择寄存器 ($8000-$BFFF)
// 7  bit  0
// ---- ----
// xxxx PPPP
//       |||
//       +++- Select 8 KB PRG ROM bank for CPU $8000-$BFFF
// 向程序ROM地址区域($8000-$FFFF)写入数据即可写入此寄存器
reg [3:0] prg_bank;
always @(posedge clk or posedge reset) begin
	if (reset) begin
		prg_bank <= 4'b0;
	end else if (ce) begin
		if (prg_write && prg_ain[15]) begin
			prg_bank <= prg_din[3:0];
		end
	end
end

// 如果prg_ain[14]=0，prg_aout[16:14]链接的是prg_bank
// prg_ain[14]=1，prg_aout[16:14]链接的是111
wire [3:0] prg_addr_17_14;
assign prg_addr_17_14 = prg_ain[14] ? 4'b1111 : prg_bank;


assign prg_aout = {1'b0, prg_addr_17_14, prg_ain[13:0]};

assign chr_aout = {6'b100_000, chr_ain[12:0]};


assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];

// The a10 VRAM address line. (Used for mirroring)
// iNES header bit 6.0: 1 = vertical mirroring, 0 = horizontal mirroring.
// Vertical mirroring connects CIRAM A10 to PPU A10; horizontal uses PPU A11.
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
assign vram_ce = chr_ain[13];

endmodule
