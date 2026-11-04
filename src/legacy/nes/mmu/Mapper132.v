// 中国象棋使用的mapper132
module Mapper132(
	input clk, input ce, input reset,
	input [31:0] flags,
    input [15:0] prg_ain, output [18:0] prg_aout,
    input prg_read, prg_write,                   // Read / write signals
    input [7:0] prg_din, output reg [7:0] prg_dout,
    output prg_allow,                            // Enable access to memory for the specified operation.
    input [13:0] chr_ain, output [18:0] chr_aout,
    output chr_allow,							// Allow write
    output vram_a10,							// Value for A10 address line
    output vram_ce								// True if the address should be routed to the internal 2kB VRAM.
);

// PRG       = 0....
// CHR       = 10...
// CHR VRAM  = 1100
// CPU RAM   = 1110 ... (后面还有15条地址线)
// CARTRAM   = 1111 (CPU $6000-$7FFF)

reg [2:0] P, R, O;
reg S, V, C;
reg prg_a15, chr_a14, chr_a13;

// 读取过程
always @(posedge clk or posedge reset) begin
	if (reset) begin
		prg_dout <= 8'b0;
	end else if (ce) begin
		if (prg_read && (prg_ain == 16'h4100)) begin
			prg_dout <= {4'b0, S^V, R};
		end
	end
end

// 写入过程
always @(posedge clk or posedge reset) begin
	if (reset) begin
		{P, R, O, S, V, C} <= 'b0;
		{prg_a15, chr_a14, chr_a13} <= 3'b000;
	end else if (ce) begin
		if (prg_write && (prg_ain == 16'h4100)) begin
			// 写入$4100
			if (C == 1'b1) begin
				// If Increment is set, internal register 'RRR' <- 'RRR'+1
				R <= R + 1'b1;
			end else if (V == 1'b0) begin
				// if Invert is clear, copy internal register 'PPP' to 'RRR'
				R <= P;
			end else if (V == 1'b1) begin	
				// if Invert is set, copy '~PPP' to 'RRR'
				R <= ~P;
			end
		end else if (prg_write && (prg_ain == 16'h4101)) begin
			// 写入$4101
			V <= prg_din[0];
		end else if (prg_write && (prg_ain == 16'h4102)) begin
			// 写入$4102
			S <= prg_din[3];
			P <= prg_din[2:0];
		end else if (prg_write && (prg_ain == 16'h4103)) begin
			// 写入$4103
			C <= prg_din[0];
		end else if (prg_write && prg_ain[15]) begin
			{prg_a15, chr_a14, chr_a13} <= R;
		end
	end
end

assign prg_aout = {3'b000, prg_a15, prg_ain[14:0]};

assign chr_aout = {4'b1000, {chr_a14, chr_a13}, chr_ain[12:0]};

assign prg_allow = prg_ain[15] && !prg_write;	// 允许访问外部存储器
assign chr_allow = flags[15];


assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];



endmodule
