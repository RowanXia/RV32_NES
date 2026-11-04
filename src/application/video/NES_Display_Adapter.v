module NES_Display_Adapter(
    input clk_nes,
    input rst_n,
    input [8:0] cycle,
    input [8:0] scanline,
    input [5:0] color,

    // 向显存输出的信号
    output      	wr_clk,
    output      	wr_rst,
    output      	wr_en,    // 写使能
    output [5:0]	wr_data,
	output [15:0]	wr_addr,

    output reg	HDMI_read_en /* synthesis PAP_MARK_DEBUG="true" */    // fifo中已有足够数据，允许hdmi接口读取
);

assign wr_rst = !rst_n;

// 刚刚上电，正在发送第一帧画面的数据，此时的数据丢弃掉，不发送到fifo中
reg first_frame_after_reset/* synthesis PAP_MARK_DEBUG="true" */;
always @(posedge clk_nes or negedge rst_n) begin
    if (!rst_n) begin
        first_frame_after_reset <= 'b1;
    end else if (first_frame_after_reset && scanline == 'd260) begin
        first_frame_after_reset <= 'b0;
    end
end

// 使能HDMI读取的信号
always @(posedge clk_nes or negedge rst_n) begin
    if (!rst_n) begin
        HDMI_read_en <= 'b0;
    end else if (!first_frame_after_reset && scanline == 'd240) begin
        // Full framebuffer: enable after all 240 visible rows have been written.
        HDMI_read_en <= 'b1;
    end
end

assign wr_clk = clk_nes;        // 读时钟采用nes的时钟
assign wr_data = color;

// 像素有效信号
wire pix_available = (scanline <= 239) && cycle < 256;


// cycle 延迟一拍的信号
reg [8:0] cycle_delay;
always @(posedge clk_nes or negedge rst_n) begin
    if (!rst_n) begin
        cycle_delay <= 'b0;
    end else begin
        cycle_delay <= cycle;
    end
end

// 指示输入的cycle已经发生变化
wire enter_new_cycle = |(cycle_delay ^ cycle);

// 如果在加速生成像素状态，则wr_en脉冲宽度变为两倍
wire read_pulse = enter_new_cycle;

// 输出fifo写入使能信号
assign wr_en = pix_available
	& read_pulse
	& !first_frame_after_reset;

// 写地址生成
// scanline * 256 + cycle
assign wr_addr = {16{pix_available}} & {scanline[7:0], cycle[7:0]};


endmodule