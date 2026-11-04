// 将PPU和CPU的访问导向到同一块RAM内
module MemoryMultiplex(
	input clk, input ce, input reset,
    input [18:0] prg_addr, input prg_read, input prg_write, input [7:0] prg_din,
    input [18:0] chr_addr, input chr_read, input chr_write, input [7:0] chr_din,
	
    // Access signals for the SRAM.
    output [18:0] memory_addr,   // address to access
    output memory_read_cpu,      // read into CPU latch
    output memory_read_ppu,      // read into PPU latch
    output memory_write,         // is a write operation
    output [7:0] memory_dout
);

reg saved_prg_read, saved_prg_write;
assign memory_addr = (chr_read || chr_write) ? chr_addr : prg_addr;
assign memory_write = (chr_read || chr_write) ? chr_write : saved_prg_write;
assign memory_read_ppu = chr_read;
assign memory_read_cpu = !(chr_read || chr_write) && (prg_read || saved_prg_read);
assign memory_dout = chr_write ? chr_din : prg_din;


always @(posedge clk or posedge reset) begin
	if (reset) begin 
		saved_prg_read <= 'b0;
		saved_prg_write <= 'b0;
	end else if (ce) begin
		if (chr_read || chr_write) begin
			saved_prg_read <= prg_read || saved_prg_read;	// 如果此时有chr的读写插入，则暂时挂起CPU的读写操作
			saved_prg_write <= prg_write || saved_prg_write;
		end else begin
			saved_prg_read <= 0;
			saved_prg_write <= prg_write;
		end
	end
end


endmodule