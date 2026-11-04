module NES_AHB_interface (
    input clk_21MHZ,
    input HRESP, output reg bus_error,
    input rst_n,

    input [31:0] mapper_flags,

    output [15:0] sample,        // APU生成的音频信号
    output [5:0] color,                // NES输出的像素，用6位

    // 手柄输入数据
	input	[7:0] joypad_p1,
	input	[7:0] joypad_p2,
	
	
    input [4:0] audio_channels, // 使能的音频通道

    output [8:0] cycle,                  // 来自ppu的cycle
    output [8:0] scanline,

    // AHB interface   
    output [31:0] HADDR /* synthesis PAP_MARK_DEBUG="true" */ , 
    output [31:0] HWDATA, 
    input  [31:0] HRDATA, 
    output        HWRITE, 
    input         HREADY,
    output [1:0]  HTRANS,
    output [2:0]  HSIZE 

);

reg [2:0] nes_ce;
wire bus_busy;

// NES is clocked at every 4th cycle.
// 八分频
always @(posedge clk_21MHZ or negedge rst_n) begin
    if (!rst_n) begin
        nes_ce <= 'b0;
    end else begin
        if (!bus_error && !(nes_ce == 1 && bus_busy)) nes_ce <= nes_ce + 1;
    end
end

wire run_mem = (nes_ce == 0) && rst_n;
wire run_nes = (nes_ce == 7) && rst_n;
//***********

wire [18:0] memory_addr;
wire memory_read_cpu;
wire memory_read_ppu;
wire memory_write;
reg [7:0] memory_din_cpu;  
reg [7:0] memory_din_ppu;
wire [7:0] memory_dout;

// 手柄数据相关
wire joypad_strobe;        // Set to 1 to strobe joypads. Then set to zero to keep the value.
wire [1:0] joypad_clock;     // Set to 1 for each joypad to clock it.
                            // 手柄状态移位寄存器的时钟
wire [1:0] joypad_data; // 1p、2p玩家的按键数据

NES nes(
    .clk(clk_21MHZ),
    .reset(!rst_n ),        // 高有效复位！！！！！！
    .ce(run_nes),
    .mapper_flags(mapper_flags),

    .sample(sample),        // APU生成的音频信号
    .color(color),                // NES输出的像素，用6位

    // 手柄相关
    .joypad_strobe(joypad_strobe),// Set to 1 to strobe joypads. Then set to zero to keep the value.
    .joypad_clock(joypad_clock), // Set to 1 for each joypad to clock it.
                                // 手柄状态移位寄存器的时钟
    .joypad_data(joypad_data), // 1p、2p玩家的按键数据
    .audio_channels(audio_channels), // 使能的音频通道

    // Access signals for the SRAM.
    .memory_addr(memory_addr),        // 访问的地址           
    .memory_read_cpu(memory_read_cpu),// CPU读信号         
    .memory_din_cpu(memory_din_cpu),  // 在下个周期，CPU读的数据，8bit
    .memory_read_ppu(memory_read_ppu),// PPU读信号         
    .memory_din_ppu(memory_din_ppu),  // 在下个周期，PPU读的数据  
    .memory_write(memory_write),      // 写信号            
    .memory_dout(memory_dout),        // 写数据            
                                                        
    .cycle(cycle),                  // 来自ppu的cycle
    .scanline(scanline)
           
);

assign HSIZE = 3'b000;        // 固定为8位读写

// AHB-Lite byte master, one outstanding transfer.
localparam IDLE=0, ADDR=1, DATA=2;
reg [1:0] state;
assign bus_busy=(state!=IDLE);
reg [18:0] address_q;
reg [7:0] write_data_q;
reg write_q, read_cpu_q, read_ppu_q;
assign HADDR={13'b0,address_q};
assign HWRITE=write_q;
assign HTRANS=(state==ADDR)?2'b10:2'b00;
assign HWDATA={4{write_data_q}};
wire [31:0] shifted_read=HRDATA >> (8*address_q[1:0]);
always @(posedge clk_21MHZ or negedge rst_n) begin
 if(!rst_n) begin
  state<=IDLE;address_q<=0;write_data_q<=0;write_q<=0;
  read_cpu_q<=0;read_ppu_q<=0;memory_din_cpu<=0;memory_din_ppu<=0;bus_error<=0;
 end else case(state)
 IDLE: if(run_mem && (memory_write||memory_read_cpu||memory_read_ppu)) begin
  address_q<=memory_addr;write_data_q<=memory_dout;write_q<=memory_write;
  read_cpu_q<=memory_read_cpu;read_ppu_q<=memory_read_ppu;state<=ADDR;
 end
 ADDR: if(HREADY) state<=DATA;
 DATA: if(HREADY) begin
  if(HRESP) bus_error<=1'b1;
  else if(!write_q) begin
   if(read_cpu_q) memory_din_cpu<=shifted_read[7:0];
   if(read_ppu_q) memory_din_ppu<=shifted_read[7:0];
  end
  state<=IDLE;
 end
 default:state<=IDLE;
 endcase
end

// 手柄输入控制
reg [1:0] joypad_clock_delay;
always @(posedge clk_21MHZ or negedge rst_n) begin
	if (!rst_n) begin
		joypad_clock_delay <= 2'b0;
	end else begin
		joypad_clock_delay <= joypad_clock;
	end
end
wire [1:0] joypad_clock_negedge = {
	joypad_clock_delay[1] & !joypad_clock[1],
	joypad_clock_delay[0] & !joypad_clock[0]
};

// 移位输入
reg [7:0] joypad_p1_shift_reg;
reg [7:0] joypad_p2_shift_reg;
always @(posedge clk_21MHZ or negedge rst_n) begin
	if (!rst_n) begin
		joypad_p1_shift_reg <= 8'b0;
		joypad_p2_shift_reg <= 8'b0;
	end else if (joypad_strobe) begin
		// strobe为1时，移位寄存器重装初值
		joypad_p1_shift_reg <= joypad_p1;
		joypad_p2_shift_reg <= joypad_p2;
	end else begin
		if (joypad_clock_negedge[0]) begin
			joypad_p1_shift_reg <= {1'b1, joypad_p1_shift_reg[7:1]};
		end
		if (joypad_clock_negedge[1]) begin
			joypad_p2_shift_reg <= {1'b1, joypad_p2_shift_reg[7:1]};
		end
	end
end

// 1p、2p玩家的按键数据
// With strobe high, reads report live A; after eight reads, shift in 1s.
assign joypad_data = joypad_strobe ? {joypad_p2[0], joypad_p1[0]} :
                                    {joypad_p2_shift_reg[0], joypad_p1_shift_reg[0]};


endmodule
