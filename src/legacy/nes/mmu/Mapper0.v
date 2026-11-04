// No mapper chip
module Mapper0(input clk, input ce,
            input [31:0] flags,
            input [15:0] prg_ain,
            output [18:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [18:0] chr_aout,
            output chr_allow,                      // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.


assign prg_aout = {4'b0000, prg_ain[14:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {6'b100_000, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];


endmodule