// PRG       = 0....
// CHR       = 10...
// CHR VRAM  = 1100
// CPU RAM   = 1110 ... (后面还有15条地址线)
// CARTRAM   = 1111 (CPU $6000-$7FFF)

`include "DEFINES.vh"

module MultiMapper(
	input clk, input ce, input ppu_ce, input reset,
	input [19:0] ppuflags,	// Misc flags from PPU for MMC5 cheating
	input [31:0] flags,		// Misc flags from ines header {prg_size(3), chr_size(3), mapper(8)}
	input [15:0] prg_ain,
	output reg [18:0] prg_aout,		// PRG Input / Output Address Lines
	input prg_read, prg_write,                       // PRG Read / write signals
	input [7:0] prg_din, output reg [7:0] prg_dout,  // PRG Data
	input [7:0] prg_from_ram,                        // PRG Data from RAM
	output reg prg_allow,                            // PRG Allow write access
	input chr_read,                                  // Read from CHR
	input [13:0] chr_ain, output reg [18:0] chr_aout,// CHR Input / Output Address Lines
	output reg [7:0] chr_dout,                       // Value to override CHR data with
	output reg has_chr_dout,                         // True if CHR data should be overridden
	output reg chr_allow,                            // CHR Allow write
	output reg vram_a10,                             // CHR Value for A10 address line
	output reg vram_ce,                              // CHR True if the address should be routed to the internal 2kB VRAM.
	output reg irq
);

`ifdef ONCHIP_MEM        // 直接映射
always @(*) begin
	prg_aout = {3'b000, prg_ain[15:0]};        // 直接接地址线的15:0
	chr_aout = {5'b0_0100, chr_ain[13:0]};
	
	has_chr_dout = 0;
	prg_dout = 8'hff;
	chr_dout = 8'hff;
	chr_allow = flags[15];
	prg_allow = prg_ain[15] & !prg_write | (prg_ain < 'h2000);
	
	vram_ce = chr_ain[13];
	vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
	
	irq= 1'b0;
end

`else

// MAPPER 0
wire map0_prg_allow, map0_vram_a10, map0_vram_ce, map0_chr_allow;
wire [18:0] map0_prg_addr, map0_chr_addr;
Mapper0 mapper0(clk, ce, flags, prg_ain, map0_prg_addr, prg_read, prg_write, prg_din, map0_prg_allow,
            chr_ain, map0_chr_addr, map0_chr_allow, map0_vram_a10, map0_vram_ce);

// MAPPER 1
wire map1_prg_allow, map1_vram_a10, map1_vram_ce, map1_chr_allow;
wire [18:0] map1_prg_addr, map1_chr_addr;
Mapper1 mapper1(clk, ce, reset, flags, prg_ain, map1_prg_addr, prg_read, prg_write, prg_din, map1_prg_allow,
            chr_ain, map1_chr_addr, map1_chr_allow, map1_vram_a10, map1_vram_ce);

// MAPPER 2
wire map2_prg_allow, map2_vram_a10, map2_vram_ce, map2_chr_allow;
wire [18:0] map2_prg_addr, map2_chr_addr;
Mapper2 mapper2(clk, ppu_ce, reset, flags, prg_ain, map2_prg_addr, prg_read, prg_write, prg_din, map2_prg_allow,
			chr_read, chr_ain, map2_chr_addr, map2_chr_allow, map2_vram_a10, map2_vram_ce);

// MAPPER 3
wire map3_prg_allow, map3_vram_a10, map3_vram_ce, map3_chr_allow;
wire [18:0] map3_prg_addr, map3_chr_addr;
Mapper3 mapper3(clk, ppu_ce, reset, flags, prg_ain, map3_prg_addr, prg_read, prg_write, prg_din, map3_prg_allow,
			chr_read, chr_ain, map3_chr_addr, map3_chr_allow, map3_vram_a10, map3_vram_ce);
			
// MAPPER 132
wire map132_prg_allow, map132_vram_a10, map132_vram_ce, map132_chr_allow;
wire [18:0] map132_prg_addr, map132_chr_addr;
wire [7:0] map132_prg_dout;
Mapper132 mapper132(
	.clk(clk), .ce(ce), .reset(reset),
	.flags(flags),
    .prg_ain(prg_ain), .prg_aout(map132_prg_addr),
    .prg_read(prg_read), .prg_write(prg_write),
    .prg_din(prg_din), .prg_dout(map132_prg_dout),
    .prg_allow(map132_prg_allow),
    .chr_ain(chr_ain), .chr_aout(map132_chr_addr),
    .chr_allow(map132_chr_allow),	// Allow write
    .vram_a10(map132_vram_a10),		// Value for A10 address line
    .vram_ce(map132_vram_ce)		// True if the address should be routed to the internal 2kB VRAM.
);

  
// Mask 
reg [3:0] prg_mask;
reg [3:0] chr_mask;

always @(*) begin
	// Safe defaults for mapper outputs that are only overridden by a few
	// cartridges.  Keeping these assignments outside the case avoids inferred
	// latches and prevents values from a previously selected game leaking into
	// the next game after software changes mapper_flags.
	irq = 1'b0;
	prg_dout = 8'hff;
	has_chr_dout = 1'b0;
	chr_dout = 8'hff;

	case(flags[10:8])		// log2(PRG ROM size / 16 KiB)
		0: prg_mask = 4'b0000;
		1: prg_mask = 4'b0001;
		2: prg_mask = 4'b0011;
		3: prg_mask = 4'b0111;
		4: prg_mask = 4'b1111;
    default: prg_mask = 4'b1111;
    endcase

    case(flags[13:11])		// log2(CHR ROM size / 8 KiB)
		0: chr_mask = 4'b0000;
		1: chr_mask = 4'b0001;
		2: chr_mask = 4'b0011;
		3: chr_mask = 4'b0111;
		4: chr_mask = 4'b1111;
	default: chr_mask = 4'b1111;
    endcase
        
    case(flags[7:0])
		0:
			{prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}
				= {map0_prg_addr, map0_prg_allow, map0_chr_addr, map0_vram_a10, map0_vram_ce, map0_chr_allow};
		1:
			{prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}
				= {map1_prg_addr, map1_prg_allow, map1_chr_addr, map1_vram_a10, map1_vram_ce, map1_chr_allow};
		
		2:
			{prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}
				= {map2_prg_addr, map2_prg_allow, map2_chr_addr, map2_vram_a10, map2_vram_ce, map2_chr_allow};
		
		3:
			{prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}
				= {map3_prg_addr, map3_prg_allow, map3_chr_addr, map3_vram_a10, map3_vram_ce, map3_chr_allow};
		
		8'd127, 8'd132: begin // Keep integrated-board legacy 127 alias.
			{prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}
				= {map132_prg_addr, map132_prg_allow, map132_chr_addr, map132_vram_a10, map132_vram_ce, map132_chr_allow};
			prg_dout = map132_prg_dout;
		end
			
		
		default: begin 
			{prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow} =
				{map0_prg_addr, map0_prg_allow, map0_chr_addr, map0_vram_a10, map0_vram_ce, map0_chr_allow};
		end
    endcase
	
	// 对PRG的地址做限制
    if (prg_aout[18] == 0) begin
		prg_aout[17:0] = {prg_aout[17:14] & prg_mask, prg_aout[13:0]};
	end
	
	// 限制CHR的地址
    if (chr_aout[18:17] == 2'b10) begin
		chr_aout[16:0] = {chr_aout[16:13] & chr_mask, chr_aout[12:0]};
	end
	
    // 把CHR地址remap到VRAM
    chr_aout = vram_ce ? {8'b1100_0000, vram_a10, chr_ain[9:0]} : chr_aout;

    // CPU的2KB内部RAM
    prg_aout = (prg_ain < 'h2000) ? {8'b1110_0000, prg_ain[10:0]} : prg_aout;
    prg_allow = prg_allow || (prg_ain < 'h2000);

end
`endif


endmodule
