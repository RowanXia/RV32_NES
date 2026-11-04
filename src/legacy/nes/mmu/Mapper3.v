// mapper3
module Mapper3(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [18:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input chr_read, input [13:0] chr_ain, output [18:0] chr_aout,
            output chr_allow,                      // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.

// CPU $6000-$7FFF: 2KB的PRG-RAM
// CPU $8000-$FFFF: 32KB PRG-ROM
// PPU $0000-$1FFF: 8KB映射到32KB的CHR ROM

// 对$8000 - $FFFF写入，即可写入bank选择寄存器
// [.... ..BA]
//         ||
//         ++- CHR A14..A13 (8 KiB bank)
reg [1:0] chr_bank;
always @(posedge clk or posedge reset) begin
	if (reset) begin
		chr_bank <= 2'b0;
	end else if (ce) begin
		if (prg_write && prg_ain[15]) begin
			// 32KB版本
			chr_bank <= prg_din[1:0];
		end
	end
end

// PRG       = 0....
// CHR       = 10...
// CHR VRAM  = 1100
// CPU RAM   = 1110 ... (后面还有15条地址线)(CPU $6000-$7FFF)
// CARTRAM   = 1111 

// 如果CPU地址在$6000-$7FFF，把它引导到1110开头的2KB地址

assign prg_aout = (prg_ain[15:13] == 3'b011) ?
			{8'b1110_0000, prg_ain[10:0]}
		:
			{4'b0000, prg_ain[14:0]};

assign chr_aout = {4'b1000, chr_bank, chr_ain[12:0]};


assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];

// The a10 VRAM address line. (Used for mirroring)
// iNES header bit 6.0: 1 = vertical mirroring, 0 = horizontal mirroring.
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
assign vram_ce = chr_ain[13];

endmodule
