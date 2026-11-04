module Display_Controller(
    input clk,
    input rst_n,
	input video_test,
    output frame_ready,
    input [1:0] diagnostic_mode,output [7:0] video_trace,
	input hdmi_init_over,		// hdmi控制芯片是否已初始化完成

    input [31:0] status_reg,        // 模式控制寄存器
    
    // 来自nes的像素信号
    input [8:0] cycle,
    input [8:0] scanline,
    input [5:0] color,
	
	// AHB总线接口
    input        HSEL,       // 从设备选择
    input [31:0] HADDR,      // 地址
    input [31:0] HWDATA,     // 写数据
    input        HWRITE,     // 读写控制
    input [1:0]  HTRANS,     // 传输类型
    input [2:0]  HSIZE,      // 传输大小
    input        HREADY,     // 传输就绪
    
    output[31:0] HRDATA,     // 读数据
    output       HREADYOUT,  // 从设备就绪
    output		 HRESP,      // 响应
    
    // hdmi接口
    input        hdmi_clk,

    output       PIX_CLK,        //pixclk                           
    output       VSYNC_o, 
    output       HSYNC_o, 
    output       DATAENABLE_o,
    output [7:0] RED_o, 
    output [7:0] GREEN_o, 
    output [7:0] BLUE_o

);

// 控制寄存器
wire is_nes_working = status_reg[0];	// 0: CPU显示画面；1: nes显示画面
wire enable_HDMI = status_reg[1];		// 启动HDMI输出



// 写入显存的AHB总线信息

wire wr_clk_ahb, wr_rst_ahb, wr_en_ahb;
wire [5:0] wr_data_ahb;
wire [15:0] wr_addr_ahb;

// AHB直接写入显存模块
Graphic_Ram_AHB_Interface ahb_interface(
    // AHB总线接口
    .HCLK		(clk	),       // 时钟
    .HRESETn	(rst_n & !is_nes_working),    // 只有NES没有工作的时候，AHB总线接口才能工作
    .HSEL		(HSEL	),       // 从设备选择
    .HADDR		(HADDR	),      // 地址
    .HWDATA		(HWDATA	),     // 写数据
    .HWRITE		(HWRITE	),     // 读写控制
    .HTRANS		(HTRANS	),     // 传输类型
    .HSIZE		(HSIZE	),      // 传输大小
    .HREADY		(HREADY	),     // 传输就绪
    
    .HRDATA		(HRDATA),     // 读数据
    .HREADYOUT	(HREADYOUT),  // 从设备就绪
    .HRESP		(HRESP),       // 响应
	
	// 显存侧输出
    .wr_clk		(wr_clk_ahb),
    .wr_rst		(wr_rst_ahb),
    .wr_en		(wr_en_ahb),    // 写使能
    .wr_data	(wr_data_ahb),
	.wr_addr	(wr_addr_ahb)
	
);


// nes的像素信息写入显存

wire wr_clk_nes, wr_rst_nes, wr_en_nes;
wire [5:0] wr_data_nes;
wire [15:0] wr_addr_nes;
wire HDMI_read_nes_en;
assign frame_ready=HDMI_read_nes_en;

NES_Display_Adapter nes_display_adapter0(
    .clk_nes		(clk),
    .rst_n			(rst_n & is_nes_working),
    .cycle			(cycle),
    .scanline		(scanline),
    .color			(color),
	
	// 写显存
	.wr_clk			(wr_clk_nes),
	.wr_rst			(wr_rst_nes),
	.wr_en			(wr_en_nes),  
	.wr_data		(wr_data_nes),
	.wr_addr		(wr_addr_nes),
	
	// 提示HDMI模块可以读取数据了
	.HDMI_read_en	(HDMI_read_nes_en)

);

// 显存模块
wire a_wr_clk, a_wr_rst, a_wr_en;
wire [5:0] a_wr_data;
wire [15:0] a_wr_addr;

// 此时显存的输入直接连接NES Adapter
assign {a_wr_clk, a_wr_rst, a_wr_en}
	= {clk, ~rst_n, (is_nes_working ? wr_en_nes : wr_en_ahb)};
assign a_wr_data = (is_nes_working ? wr_data_nes : wr_data_ahb);
assign a_wr_addr = (is_nes_working ? wr_addr_nes : wr_addr_ahb);

// HDMI读显存的信号
wire b_rd_data_clk, b_rd_rst;
wire [5:0] b_rd_data;
wire [15:0] b_rd_addr;
wire [15:0] b_rd_addr10,b_rd_addr01,b_rd_addr11;
wire [5:0] b_rd_data10,b_rd_data01,b_rd_data11;

image_quad_framebuffer u_framebuffer(
 .wr_clk(a_wr_clk),.wr_rst(a_wr_rst),.wr_en(a_wr_en),.wr_addr(a_wr_addr),.wr_data(a_wr_data),
 .rd_clk(b_rd_data_clk),.rd_rst(b_rd_rst),
 .addr00(b_rd_addr),.addr10(b_rd_addr10),.addr01(b_rd_addr01),.addr11(b_rd_addr11),
 .data00(b_rd_data),.data10(b_rd_data10),.data01(b_rd_data01),.data11(b_rd_data11));

wire hdmi_domain_rst_n;
nes_reset_sync hdmi_domain_reset(.clk(hdmi_clk),.arst_n(rst_n),.rst_n(hdmi_domain_rst_n));
wire [8:0] hdmi_controls;
nes_cdc_mailbox #(.WIDTH(9)) controls_cdc(
 .src_clk(clk),.src_rst_n(rst_n),.src_data({diagnostic_mode,hdmi_init_over,video_test,HDMI_read_nes_en,status_reg[3:0]}),
 .dst_clk(hdmi_clk),.dst_rst_n(hdmi_domain_rst_n),.dst_data(hdmi_controls));
wire [1:0] display_size=hdmi_controls[3:2];

// Six independent sticky flags cross back to HCLK through two flip-flops.
wire [5:0] trace_hdmi,trace_sync;
genvar ti;
generate for(ti=0;ti<6;ti=ti+1)begin:g_trace_cdc
 wire meta;
 GTP_DFF_C meta_ff(.CLK(clk),.C(~rst_n),.D(trace_hdmi[ti]),.Q(meta));
 GTP_DFF_C sync_ff(.CLK(clk),.C(~rst_n),.D(meta),.Q(trace_sync[ti]));
end endgenerate
reg sw_seen,init_seen,sw_drop,init_drop;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin sw_seen<=0;init_seen<=0;sw_drop<=0;init_drop<=0;end
 else begin
 if(status_reg[1])sw_seen<=1;
 if(hdmi_init_over)init_seen<=1;
 if(sw_seen && !status_reg[1])sw_drop<=1;
 if(init_seen && !hdmi_init_over)init_drop<=1;
 end
end
assign video_trace={init_drop,trace_sync[5:1],sw_drop,trace_sync[0]};

// HDMI接口
wire HDMI_rst_n;
nes_reset_sync hdmi_enable_reset(.clk(hdmi_clk),
 .arst_n(hdmi_domain_rst_n & hdmi_controls[1] & hdmi_controls[6] & (~hdmi_controls[0] | hdmi_controls[4])),
 .rst_n(HDMI_rst_n));
HDMI_Controller hdmi_controller0(
    .hdmi_clk		(hdmi_clk),
    .rst_n			(hdmi_domain_rst_n),
    .video_enable(HDMI_rst_n),.video_test(hdmi_controls[5]),
    .diagnostic_mode(hdmi_controls[8:7]),.trace_sticky(trace_hdmi),

    // 读取显存的信号
    .rd_clk			(b_rd_data_clk),
    .rd_rst			(b_rd_rst),   
    .rd_data		(b_rd_data),
    .rd_data10(b_rd_data10),.rd_data01(b_rd_data01),.rd_data11(b_rd_data11),
    .rd_addr10(b_rd_addr10),.rd_addr01(b_rd_addr01),.rd_addr11(b_rd_addr11),
	.rd_addr		(b_rd_addr),
	
	.display_size	(display_size),

    // HDMI接口输出
    .PIX_CLK(PIX_CLK),        //pixclk                           
    .VSYNC_o(VSYNC_o), 
    .HSYNC_o(HSYNC_o), 
    .DATAENABLE_o(DATAENABLE_o),
    .RED_o(RED_o), 
    .GREEN_o(GREEN_o), 
    .BLUE_o(BLUE_o)

);



endmodule
