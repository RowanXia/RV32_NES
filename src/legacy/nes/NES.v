// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.

// 输入时钟为21MHz
module NES(input clk, input reset, input ce,
           input [31:0] mapper_flags,
           output [15:0] sample, // sample generated from APU
           output [5:0] color,  // NES输出的像素，用6位
           output joypad_strobe,// Set to 1 to strobe joypads. Then set to zero to keep the value.
           output [1:0] joypad_clock, // Set to 1 for each joypad to select it.
           input [1:0] joypad_data, // 1p、2p玩家的按键数据
           input [4:0] audio_channels, // 使能的音频通道

           
           // 访问RAM中数据
           output [18:0] memory_addr,   // 访问的地址
           output memory_read_cpu,      // CPU读信号
           input [7:0] memory_din_cpu,  // 在下个周期，CPU读的数据
           output memory_read_ppu,      // PPU读信号
           input [7:0] memory_din_ppu,  // 在下个周期，PPU读的数据
           output memory_write,         // 写信号
           output [7:0] memory_dout,    // 写数据
           
           output [8:0] cycle,          // 来自ppu的cycle
           output [8:0] scanline
           
           //output reg [31:0] dbgadr,
           //output [1:0] dbgctr
        );


reg  [7:0] from_data_bus;
wire [7:0] cpu_dout;
wire odd_or_even; // Is this an odd or even clock cycle?
// The CPU runs at one third the speed of the PPU.
// CPU is clocked at cycle #2. PPU is clocked at cycle #0, #1, #2.
// CPU does its memory I/O on cycle #0. It will be available in time for cycle #2.
reg [1:0] cpu_cycle_counter;
always @(posedge clk) begin
  if (reset)
    cpu_cycle_counter <= 0;
  else if (ce)
    cpu_cycle_counter <= (cpu_cycle_counter == 2) ? 0 : cpu_cycle_counter + 1;
end
// Sample the NMI flag on cycle #0, otherwise if NMI happens on cycle #0 or #1,
// the CPU will use it even though it shouldn't be used until the next CPU cycle.
wire nmi;
reg nmi_active;
always @(posedge clk) begin
  if (reset)
    nmi_active <= 0;
  else if (ce && cpu_cycle_counter == 0)
    nmi_active <= nmi;
end
wire apu_ce =        ce && (cpu_cycle_counter == 2);
// -- CPU
wire [15:0] cpu_addr;
wire cpu_mr, cpu_mw;
wire pause_cpu;
reg apu_irq_delayed;
reg mapper_irq_delayed;

/*
CPU cpu(clk,
        apu_ce && !pause_cpu, reset, from_data_bus, apu_irq_delayed | mapper_irq_delayed, nmi_active, cpu_dout, cpu_addr, cpu_mr, cpu_mw);
*/
CPU cpu(
	.clk(clk), .ce(apu_ce && !pause_cpu), .reset(reset),
    .DIN(from_data_bus),
    .irq(apu_irq_delayed | mapper_irq_delayed),
    .nmi(nmi_active),
    .dout(cpu_dout),
	.aout(cpu_addr),
    .mr(cpu_mr),
    .mw(cpu_mw)
);
// -- DMA
wire [15:0] dma_aout;
wire dma_aout_enable;
wire dma_read;
wire [7:0] dma_data_to_ram;
wire apu_dma_request, apu_dma_ack;
wire [15:0] apu_dma_addr;
// Determine the values on the bus outgoing from the CPU chip (after DMA / APU)
wire [15:0] addr = dma_aout_enable ? dma_aout : cpu_addr;
wire [7:0]  dbus = dma_aout_enable ? dma_data_to_ram : cpu_dout;
wire mr_int      = dma_aout_enable ? dma_read : cpu_mr;
wire mw_int      = dma_aout_enable ? !dma_read : cpu_mw;

DmaController dma(.clk(clk), .ce(apu_ce), .reset(reset), 
                  .odd_cycle(odd_or_even),                    // Even or odd cycle
                  .sprite_trigger((addr == 'h4014) && mw_int),     // Sprite trigger
                  .dmc_trigger(apu_dma_request),                // DMC Trigger
                  .cpu_read(cpu_mr),                         // CPU in a read cycle?
                  .data_from_cpu(cpu_dout),                       // Data from cpu
                  .data_from_ram(from_data_bus),                  // Data from RAM etc.
                  .dmc_dma_addr(apu_dma_addr),                   // DMC addr
                  .aout(dma_aout),
                  .aout_enable(dma_aout_enable), 
                  .read(dma_read),
                  .data_to_ram(dma_data_to_ram),
                  .dmc_ack(apu_dma_ack),
                  .pause_cpu(pause_cpu)
);

// -- Audio Processing Unit  
wire apu_cs = addr >= 'h4000 && addr < 'h4018;
wire [7:0] apu_dout;
wire apu_irq;
APU apu(
	.clk(clk), .ce(apu_ce), .reset(reset),
    .ADDR(addr[4:0]),  // APU Address Line
    .DIN(dbus),
    .DOUT(apu_dout), // Data from APU
    .MW(mw_int && apu_cs),          // Writes to APU
    .MR(mr_int && apu_cs),          // Reads from APU
    .audio_channels(audio_channels), // Enabled audio channels
    .Sample(sample),
    .DmaReq(apu_dma_request),      // 1 when DMC wants DMA
    .DmaAck(apu_dma_ack),           // 1 when DMC byte is on DmcData. DmcDmaRequested should go low.
    .DmaAddr(apu_dma_addr),  // Address DMC wants to read
    .DmaData(from_data_bus),    // Input data to DMC from memory.
    .odd_or_even(odd_or_even),
    .IRQ(apu_irq)
);
// Joypads are mapped into the APU's range.
wire joypad1_cs = (addr == 'h4016);
wire joypad2_cs = (addr == 'h4017);
// $4016 bit 0 is a stored latch, not an address-decode pulse.
reg joypad_strobe_q;
always @(posedge clk or posedge reset) begin
  if (reset) joypad_strobe_q <= 1'b0;
  else if (apu_ce && joypad1_cs && mw_int) joypad_strobe_q <= dbus[0];
end
assign joypad_strobe = joypad_strobe_q;
// One pulse per completed CPU bus read, including adjacent reads of the
// same port. Its delayed falling edge shifts AFTER the CPU samples DIN.
assign joypad_clock = {2{apu_ce && !reset}} &
                      {joypad2_cs && mr_int, joypad1_cs && mr_int};
    
// -- PPU
// PPU _reads_ need to happen on the same cycle the cpu runs on, to guarantee we
// see proper values of register $2002.
wire mr_ppu     = mr_int && (cpu_cycle_counter == 2);
wire mw_ppu     = mw_int && (cpu_cycle_counter == 0);
wire ppu_cs = addr >= 'h2000 && addr < 'h4000;
wire [7:0] ppu_dout;           // Data from PPU to CPU
wire chr_read, chr_write;      // If PPU reads/writes from VRAM
wire [13:0] chr_addr;          // Address PPU accesses in VRAM
wire [7:0] chr_from_ppu;       // Data from PPU to VRAM
wire [7:0] chr_to_ppu;
wire [19:0] mapper_ppu_flags;  // PPU flags for mapper cheating

/*
PPU ppu(clk, ce, reset, color, dbus, ppu_dout, addr[2:0],
        ppu_cs && mr_ppu, ,
        nmi,
        chr_read, chr_write, chr_addr, chr_to_ppu, chr_from_ppu,
        scanline, cycle, mapper_ppu_flags);
*/
PPU ppu(.clk(clk), .ce(ce), .reset(reset),   // input clock  21.48 MHz / 4. 1 clock cycle = 1 pixel
        .color		(color), // output color value, one pixel outputted every clock, 6bit
        .din		(dbus),   // input data from bus
        .dout		(ppu_dout), // output data to CPU
        .ain		(addr[2:0]),   // input address from CPU
        .read		(ppu_cs && mr_ppu),        // read
        .write		(ppu_cs && mw_ppu),       // write
        .nmi		(nmi),    // one while inside vblank
        .vram_r		(chr_read), // read from vram active
        .vram_w		(chr_write), // write to vram active
        .vram_a		(chr_addr), // vram address
        .vram_din	(chr_to_ppu), // vram input
        .vram_dout	(chr_from_ppu),
        .scanline	(scanline),
        .cycle		(cycle),
        .mapper_ppu_flags(mapper_ppu_flags)
);

// -- Memory mapping logic
wire [15:0] prg_addr = addr;
wire [7:0] prg_din = dbus;
wire prg_read = mr_int && (cpu_cycle_counter == 0) && !apu_cs && !ppu_cs;
wire prg_write = mw_int && (cpu_cycle_counter == 0) && !apu_cs && !ppu_cs;
wire prg_allow, vram_a10, vram_ce, chr_allow;
wire [18:0] prg_linaddr, chr_linaddr;
wire [7:0] prg_dout_mapper, chr_from_ppu_mapper;
wire cart_ce = (cpu_cycle_counter == 0) && ce;
wire mapper_irq;
wire has_chr_from_ppu_mapper;

MultiMapper multi_mapper(
					.clk(clk), .ce(cart_ce), .ppu_ce(ce), .reset(reset),
                	.ppuflags(mapper_ppu_flags),                           // Misc flags from PPU for MMC5 cheating
                	.flags(mapper_flags),                              // Misc flags from ines header {prg_size(3), chr_size(3), mapper(8)}
                	.prg_ain(prg_addr), 
					.prg_aout(prg_linaddr),// 把16位的程序地址转为19位的程序地址
                	.prg_read(prg_read),
					.prg_write(prg_write),                       // PRG Read / write signals
                	.prg_din(prg_din), 
					.prg_dout(prg_dout_mapper),  // PRG Data
                	.prg_from_ram(from_data_bus),                        // PRG Data from RAM
                	.prg_allow(prg_allow),                            // PRG Allow write access
                	.chr_read(chr_read),                                  // Read from CHR
                	.chr_ain(chr_addr),
					.chr_aout(chr_linaddr),                        // 把14位的图像地址转为19位的图像地址
                	.chr_dout(chr_from_ppu_mapper),                       // Value to override CHR data with
                	.has_chr_dout(has_chr_from_ppu_mapper),                         // True if CHR data should be overridden
                	.chr_allow(chr_allow),                            // CHR Allow write
                	.vram_a10(vram_a10),                             // CHR Value for A10 address line
                	.vram_ce(vram_ce),                              // CHR True if the address should be routed to the internal 2kB VRAM.
                	.irq(mapper_irq)
);


assign chr_to_ppu = has_chr_from_ppu_mapper ? chr_from_ppu_mapper : memory_din_ppu;
                           
// Mapper IRQ seems to be delayed by one PPU clock.   
// APU IRQ seems delayed by one APU clock.
always @(posedge clk or posedge reset) if (reset) begin
	mapper_irq_delayed <= 0;
	apu_irq_delayed <= 0;
end else begin
	if (ce)
    	mapper_irq_delayed <= mapper_irq;
	if (apu_ce)
    	apu_irq_delayed <= apu_irq;
end
 
// -- Multiplexes CPU and PPU accesses into one single RAM
MemoryMultiplex mem_multiplex(
    .clk(clk),
    .ce(ce),
    .reset(reset),
    .prg_addr(prg_linaddr),
    .prg_read(prg_read && prg_allow),
    .prg_write(prg_write && prg_allow),
    .prg_din(prg_din),
    .chr_addr(chr_linaddr),
    .chr_read(chr_read),
    .chr_write(chr_write && (chr_allow || vram_ce)),
    .chr_din(chr_from_ppu),
    
    // Access signals for the SRAM.
    .memory_addr(memory_addr),   // address to access
    .memory_read_cpu(memory_read_cpu),      // read into CPU latch
    .memory_read_ppu(memory_read_ppu),      // read into PPU latch
    .memory_write(memory_write),         // is a write operation
    .memory_dout(memory_dout)
);

// 数据总线调度
always @* begin
  if (apu_cs) begin
    if (joypad1_cs)
      from_data_bus = {7'b0100000, joypad_data[0]}; // 1p玩家手柄数据
    else if (joypad2_cs)
      from_data_bus = {7'b0100000, joypad_data[1]}; // 2p玩家手柄数据
    else
      from_data_bus = apu_dout;
  end else if (ppu_cs) begin
    from_data_bus = ppu_dout;
  end else if (prg_allow) begin
    from_data_bus = memory_din_cpu;
  end else begin
    from_data_bus = prg_dout_mapper;
  end
end
  
endmodule
