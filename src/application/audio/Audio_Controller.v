module Audio_Controller(
    input clk,		// 49.152MHz时钟
    input rst_n,

    // nes发送的音频信号
    input [15:0] audio_sample,

    // 发送给ms7210的信号
    output i2s_tx_ws/* synthesis PAP_MARK_DEBUG="true" */,        // 声道时钟，高为左声道，低为右声道，频率=采样率
    output i2s_tx_sc_mc/* synthesis PAP_MARK_DEBUG="true" */,     // 串行时钟/主时钟
    output i2s_tx_data0 /* synthesis PAP_MARK_DEBUG="true" */,
    output i2s_tx_data1,
    input  i2s_tx_int /* synthesis PAP_MARK_DEBUG="true" */        // 中断

);

localparam CLK_MULT = 32;        // 49.152MHz系统时钟相对于串行时钟的倍数
								 // 此处设置为32
localparam DATA_WIDTH = 16;      // 音频位宽

// 串行时钟计数器
reg [4:0] bit_cnt;
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_cnt <= 'b0;
    end else if (bit_cnt == CLK_MULT - 1) begin
        bit_cnt <= 'b0;
    end else begin
        bit_cnt <= bit_cnt + 1'b1;
    end
end

// 声道时钟计数器
reg [4:0] wclk_cnt;
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wclk_cnt <= 'b0;
    end else if ((wclk_cnt == DATA_WIDTH - 1) & (bit_cnt == CLK_MULT - 1)) begin
        wclk_cnt <= 'b0;
    end else if (bit_cnt == CLK_MULT - 1) begin
        wclk_cnt <= wclk_cnt + 1'b1;
    end
end

// SCLK：串行时钟数据，对应数字音频的每一位数据，频率=采样率*位宽*2
// WCLK：高为左声道，低为右声道，频率=采样率

// 串行时钟生成：
reg sclk;
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sclk <= 'b0;
    end else if ((bit_cnt == CLK_MULT/2 - 1) || (bit_cnt == CLK_MULT - 1)) begin
        sclk <= ~sclk;
    end
end

assign i2s_tx_sc_mc = sclk;

// 声道时钟生成：
reg wclk;
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wclk <= 'b0;
    end else if ((wclk_cnt == DATA_WIDTH - 1) & (bit_cnt == CLK_MULT - 1)) begin
        wclk <= ~wclk;
    end
end

assign i2s_tx_ws = wclk;

// 采样sample信号，并进行补码转化，过程通过流水线进行
reg [15:0] audio_sample_reg, audio_sample_comple_reg;
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        audio_sample_reg <= 16'b0;
        audio_sample_comple_reg <= 16'b0;
    end else if ((wclk_cnt == DATA_WIDTH - 1) & (bit_cnt == CLK_MULT - 1)) begin
        audio_sample_reg <= audio_sample;
        audio_sample_comple_reg <=
            {~audio_sample_reg[15], audio_sample_reg[14:0]};
    end else if (bit_cnt == CLK_MULT - 1) begin
        // 移位，输出数据
        audio_sample_comple_reg <=
            {audio_sample_comple_reg[14:0], 1'b0};
    end
end

// 输出数据
reg i2s_data;
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i2s_data <= 1'b0;
    end else if (bit_cnt == CLK_MULT - 1) begin
        i2s_data <= audio_sample_comple_reg[15];        // 数据发送从MSB开始
    end
end

assign i2s_tx_data0 = i2s_data;
assign i2s_tx_data1 = 1'b0;


endmodule