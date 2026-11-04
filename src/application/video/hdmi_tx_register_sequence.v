`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:Meyesemi 
// Engineer: Will
// 
// Create Date: 2023-01-29 20:31  
// Design Name:  
// Module Name: 
// Project Name: 
// Target Devices: Pango
// Tool Versions: 
// Description: 
//      
// Dependencies: 
// 
// Revision:
// Revision 1.0 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define UD #1
module hdmi_tx_register_sequence(
    input               clk,
    input               rstn,
                        
    output reg          init_over,
    output        [7:0] device_id,
    output reg          iic_trig ,
    output reg          w_r      ,
    output reg   [15:0] addr     ,
    output reg   [ 7:0] data_in  ,
    input               busy     ,
    input        [ 7:0] data_out ,
    input               byte_over,
    output              audio_config_ok,
    output reg [103:0]  audio_debug_regs
);
assign device_id = 8'hB2;
// Read-back is diagnostic evidence only: it is not proof of HDMI audio packets.
reg [3:0] audio_read_index;
reg [9:0] audio_read_matches;
assign audio_config_ok = &audio_read_matches;
function [15:0] audio_read_addr;
input [3:0] index;
begin
 case(index)
  0: audio_read_addr=16'h0530;
  1: audio_read_addr=16'h0535;
  2: audio_read_addr=16'h0532;
  3: audio_read_addr=16'h0531;
  4: audio_read_addr=16'h0507;
  5: audio_read_addr=16'h0503;
  6: audio_read_addr=16'h0048;
  7: audio_read_addr=16'h0570;
  8: audio_read_addr=16'h00a5;
  9: audio_read_addr=16'h051d;
  10: audio_read_addr=16'h0521;
  11: audio_read_addr=16'h0522;
  default: audio_read_addr=16'h0008;
 endcase
end
endfunction
function [7:0] audio_read_expected;
input [3:0] index;
begin
 case(index)
  0: audio_read_expected=8'h00;
  1: audio_read_expected=8'h12;
  2: audio_read_expected=8'h01;
  3: audio_read_expected=8'h84;
  7: audio_read_expected=8'h01;
  default: audio_read_expected=8'h00;
 endcase
end
endfunction
function [7:0] audio_read_mask;
input [3:0] index;
begin
 case(index)
  5,7: audio_read_mask=8'h01;
  6: audio_read_mask=8'h0f;
  8: audio_read_mask=8'h18;
  12: audio_read_mask=8'h07;
  default: audio_read_mask=8'hff;
 endcase
end
endfunction

localparam INIT_STATE_INST_NUM = 6'd19;
// SETING executes command indices 20..76. Keep this count equal to
// (last setting command index - 20), because dri_cnt starts again at zero.
localparam SETING_STATE_INST_NUM = 6'd56;


function [23:0] cmd_data;
input [6:0] index;
    begin
        case(index)
            7'd0    : cmd_data = {16'h1281,8'h04};// clock invert
            7'd1    : cmd_data = {16'h0016,8'h04};// 使能视频输入
            7'd2    : cmd_data = {16'h0009,8'h01};// 关reset
            7'd3    : cmd_data = {16'h0007,8'h09};// 
            7'd4    : cmd_data = {16'h0008,8'hF0};// I2S pad clock; clear external-MCLK/CDR selection
			7'd5    : cmd_data = {16'h0004,8'h01};// 使能音频时钟
			7'd6    : cmd_data = {16'h000C,8'h00};// 设置音频pll
			7'd7    : cmd_data = {16'h000A,8'hF0};// 复位TX PLL
            7'd8    : cmd_data = {16'h0006,8'h11};// 使能音频和视频时钟
			
            7'd9    : cmd_data = {16'h0900,8'h20};//
            7'd10   : cmd_data = {16'h0901,8'h47};//
            7'd11   : cmd_data = {16'h0904,8'h09};
            7'd12   : cmd_data = {16'h0923,8'h07};// 使能channel 0-2 的pre-driver enable
            7'd13   : cmd_data = {16'h0924,8'h44};// 设置channel 0，1为3Gbps
            7'd14  : cmd_data = {16'h0925,8'h44};// 设置channel 2和clock channel为3Gbps3Gbps
            7'd15  : cmd_data = {16'h090F,8'h80};//
            7'd16  : cmd_data = {16'h091F,8'h07};// 开启输出
            //7'65   : cmd_data = {16'h0920,8'h1E};// INT EN
            7'd17  : cmd_data = {16'h0018,8'h20};//
            7'd18   : cmd_data = {16'h05c0,8'hFE};//
			7'd19   : cmd_data = {16'h000B,8'h00};// 视频、音频复位

			// 设置阶段
			7'd20	: cmd_data = {16'h000B,8'h11};// 视频、音频复位关闭
            7'd21	: cmd_data = {16'h0507,8'h06};// 关闭音视频
            7'd22	: cmd_data = {16'h0906,8'h04};//
            7'd23	: cmd_data = {16'h0920,8'h5E};//
            7'd24	: cmd_data = {16'h0926,8'hDD};// CH1、2的电流为15.5mA
            7'd25	: cmd_data = {16'h0927,8'h0D};//
            7'd26	: cmd_data = {16'h0928,8'h88};//
            7'd27	: cmd_data = {16'h0929,8'h08};//
            7'd28	: cmd_data = {16'h0910,8'h01};//
			
			7'd29   : cmd_data = {16'h0530,8'h00};// I2S input mode
			7'd30   : cmd_data = {16'h0535,8'h12};// 16-bit I2S alignment
			7'd31   : cmd_data = {16'h0532,8'h01};// two audio channels
			7'd32   : cmd_data = {16'h0531,8'h84};// 48 kHz sample-rate code

			// AVI InfoFrame.  0x06 is the checksum for the following
			// 13-byte RGB/CEA payload used by the board reference design.
            7'd33   : cmd_data = {16'h050E,8'h20};
            7'd34   : cmd_data = {16'h050A,8'h82};// type
            7'd35   : cmd_data = {16'h0509,8'h02};// version
            7'd36   : cmd_data = {16'h050B,8'h0D};// length
            7'd37   : cmd_data = {16'h050D,8'h06};// checksum
            7'd38   : cmd_data = {16'h050D,8'h11};// RGB / scan information
            7'd39   : cmd_data = {16'h050D,8'h58};
            7'd40   : cmd_data = {16'h050D,8'h00};
            7'd41   : cmd_data = {16'h050D,8'h00};
            7'd42   : cmd_data = {16'h050D,8'h00};
            7'd43   : cmd_data = {16'h050D,8'h00};
            7'd44   : cmd_data = {16'h050D,8'h00};
            7'd45   : cmd_data = {16'h050D,8'h00};
            7'd46   : cmd_data = {16'h050D,8'h00};
            7'd47   : cmd_data = {16'h050D,8'h00};
            7'd48   : cmd_data = {16'h050D,8'h00};
            7'd49   : cmd_data = {16'h050D,8'h00};
            7'd50   : cmd_data = {16'h050D,8'h00};
            7'd51   : cmd_data = {16'h050E,8'h60};

			// Audio InfoFrame: type 0x84, version 1, length 10,
			// two-channel PCM.  Checksum 0x70 makes HB+PB sum to zero.
			7'd52   : cmd_data = {16'h050E,8'h40};
            7'd53   : cmd_data = {16'h050A,8'h84};// type
            7'd54   : cmd_data = {16'h0509,8'h01};// version
            7'd55   : cmd_data = {16'h050B,8'h0A};// length
            7'd56   : cmd_data = {16'h050D,8'h70};// checksum
            7'd57   : cmd_data = {16'h050D,8'h01};// two channels, PCM
            7'd58   : cmd_data = {16'h050D,8'h00};
            7'd59   : cmd_data = {16'h050D,8'h00};
            7'd60   : cmd_data = {16'h050D,8'h00};
            7'd61   : cmd_data = {16'h050D,8'h00};
            7'd62   : cmd_data = {16'h050D,8'h00};
            7'd63   : cmd_data = {16'h050D,8'h00};
            7'd64   : cmd_data = {16'h050D,8'h00};
            7'd65   : cmd_data = {16'h050D,8'h00};
            7'd66   : cmd_data = {16'h050D,8'h00};
            7'd67   : cmd_data = {16'h050D,8'h00};
            7'd68   : cmd_data = {16'h050D,8'h00};
            7'd69   : cmd_data = {16'h050D,8'h00};
            7'd70   : cmd_data = {16'h050E,8'h60};// enable AVI + Audio packets
            // Explicit shell/audio gates, cross-checked against ms7210.c:
            // set_hdmi_out, shell_init, audio pad input selection.
            7'd71   : cmd_data = {16'h0503,8'h00};// HDMI output (DVI bit cleared)
            7'd72   : cmd_data = {16'h0048,8'h00};// global audio control low nibble cleared
            7'd73   : cmd_data = {16'h0570,8'h81};// enable volume bypass path
            7'd74   : cmd_data = {16'h00A5,8'h00};// I2S audio pad selection
            7'd75   : cmd_data = {16'h0019,8'h07};// enable clock frequency measurement
            7'd76   : cmd_data = {16'h0507,8'h00};// clear audio/video mute
			default : cmd_data = {16'h0507,8'h00};
			
       endcase 
    end
endfunction
    //===========================================================================
    //  MS7210 driver control FSM
    //===========================================================================
    parameter    IDLE   = 6'b00_0001;
    parameter    CONECT = 6'b00_0010;
    parameter    INIT   = 6'b00_0100;
    parameter    WAIT   = 6'b00_1000;
    parameter    SETING = 6'b01_0000;
    parameter    STA_RD = 6'b10_0000;
    reg [ 5:0]   state;
    reg [ 5:0]   state_n;
    reg [ 5:0]   dri_cnt;
    reg [21:0]   delay_cnt;
    reg [ 6:0]   cmd_index;

    reg          busy_1d;
    wire         busy_falling;
    
    assign busy_falling = ((~busy) & busy_1d);
    always @(posedge clk) begin
      if(!rstn) begin audio_read_index<=0;audio_read_matches<=0;audio_debug_regs<=0;end
      else if(state==STA_RD && busy_falling) begin
        audio_debug_regs[audio_read_index*8 +: 8] <= data_out;
        if(audio_read_index<9)
          audio_read_matches[audio_read_index] <= ((data_out & audio_read_mask(audio_read_index))==audio_read_expected(audio_read_index));
        if(audio_read_index==12)
          audio_read_matches[9] <= ((data_out & 8'h07)==0);
        audio_read_index <= audio_read_index==12 ? 0 : audio_read_index+1'b1;
      end
    end
    always @(posedge clk)
    begin
        busy_1d <= busy;
    end
    //===========================================================================
    //  MS7210 driver control FSM    First Step
    always @(posedge clk)
    begin
        if(!rstn)
            state <= IDLE;
        else
            state <= state_n;
    end
    
    //===========================================================================
    //  MS7210 driver control FSM    Second Step
    always @(*)
    begin
        state_n = state;
        case(state)
            IDLE     : begin
                state_n = CONECT;
            end
            CONECT   : begin
                if(dri_cnt == 6'd1 && busy_falling && data_out == 8'h5A)
                    state_n = INIT;
                else
                    state_n = state;
            end
            INIT     : begin
                if(dri_cnt == INIT_STATE_INST_NUM && busy_falling)
                    state_n = WAIT;
                else
                    state_n = state;
            end
            WAIT     : begin
                if(delay_cnt == 22'h30D399)//)//
                    state_n = SETING;
                else
                    state_n = state;
            end
            SETING   : begin
                if(dri_cnt == SETING_STATE_INST_NUM && busy_falling)
                    state_n = STA_RD;
                else
                    state_n = state;
            end
            STA_RD   : begin
                state_n = state;
            end
            default  : begin
                state_n = IDLE;
            end
        endcase
    end
    
    //===========================================================================
    //  MS7210 driver control FSM    Third Step
    always @(posedge clk)
    begin
        if(!rstn)
            dri_cnt <= 6'd0;
        else
        begin
            case(state)
                IDLE     ,
                WAIT     ,
                STA_RD   : dri_cnt <= 6'd0;
                CONECT   : begin
                    if(busy_falling)
                    begin
                        if(dri_cnt == 6'd1)
                            dri_cnt <= 6'd0;
                        else
                            dri_cnt <= dri_cnt + 6'd1;
                    end
                    else
                        dri_cnt <= dri_cnt;
                end
                INIT     : begin
                    if(busy_falling)
                    begin
                        if(dri_cnt == INIT_STATE_INST_NUM)
                            dri_cnt <= 6'd0;
                        else
                            dri_cnt <= dri_cnt + 6'd1;
                    end
                    else
                        dri_cnt <= dri_cnt;
                end
                SETING   : begin
                    if(busy_falling)
                    begin
                        if(dri_cnt == SETING_STATE_INST_NUM)
                            dri_cnt <= 6'd0;
                        else
                            dri_cnt <= dri_cnt + 6'd1;
                    end
                    else
                        dri_cnt <= dri_cnt;
                end
                default  : dri_cnt <= 6'd0;
            endcase
        end
    end
    
    always @(posedge clk)
    begin
        if(state == WAIT)
        begin
            if(delay_cnt == 22'h30D399)
                delay_cnt <= 22'd0;
            else
                delay_cnt <= delay_cnt + 22'd1;
        end
        else
            delay_cnt <= 22'd0;
    end
    
    always @(posedge clk)
    begin
        if(!rstn)
            iic_trig <= 1'd0;
        else
        begin
            case(state)
                IDLE     : iic_trig <= 1'b1;
                WAIT     : iic_trig <= (delay_cnt == 22'h30D399);
                CONECT   ,
                INIT     ,
                SETING   ,
                STA_RD   : iic_trig <= busy_falling;
                default  : iic_trig <= 1'd0;
            endcase
        end
    end
    
    always @(posedge clk)
    begin
        if(!rstn)
            w_r <= 1'd1;
        else
        begin
            case(state)
                IDLE     : w_r <= 1'b1;
                CONECT   : begin
                    if(dri_cnt == 6'd0 && busy_falling)
                        w_r <= 1'b0;
                    else if(dri_cnt == 6'd1 && busy_falling)
                        w_r <= 1'b1;
                    else
                        w_r <= w_r;
                end
                INIT     ,
                STA_RD   ,
                WAIT     : w_r <= w_r;
                SETING   : begin
                    if(dri_cnt == SETING_STATE_INST_NUM && busy_falling)
                        w_r <= 1'b0;
                    else
                        w_r <= w_r;
                end
                default  : w_r <= 1'b1;
            endcase
        end
    end
    
    always @(posedge clk)
    begin
        if(!rstn)
            cmd_index <= 7'd0;
        else
        begin
            case(state)
                IDLE     : cmd_index <= 7'd0;
                CONECT   : cmd_index <= 7'd0;
                INIT     ,
                SETING   :begin
                    if(byte_over)
                        cmd_index <= cmd_index + 1'b1;
                    else
                        cmd_index <= cmd_index;
                end
                WAIT     ,
                STA_RD   : cmd_index <= cmd_index;
                default  : cmd_index <= 7'd0;
            endcase
        end
    end
    
    reg [23:0] cmd_iic;
    always@(posedge clk)
	begin
		if(~rstn)
			cmd_iic <= 0;
		else if(state == IDLE)
			cmd_iic <= 24'd0;
        else //if(state == WAIT || state == SETING)
            cmd_iic <= cmd_data(cmd_index);
	end
    
    always @(posedge clk)
    begin
        if(!rstn)
        begin
            addr    <= 16'd0;
            data_in <= 8'd0;
        end
        else
        begin
            case(state)
                IDLE     : begin
                    addr    <= 16'h0003;
                    data_in <= 8'h5A;
                end
                CONECT   : begin
                    if(dri_cnt == 6'd1 && busy_falling && data_out == 8'h5A)
                    begin
                        addr    <= cmd_iic[23:8];
                        data_in <= cmd_iic[ 7:0];
                    end
                    else
                    begin
                        addr    <= addr;
                        data_in <= data_in;
                    end
                end
                INIT     ,
                WAIT     ,
                SETING   :begin
                	addr    <= cmd_iic[23:8];
                    data_in <= cmd_iic[ 7:0];
                end
                STA_RD   :begin
                    addr    <= audio_read_addr(audio_read_index);
                    data_in <= 8'd0;
                end
                default  : begin
                    addr    <= 0;
                    data_in <= 0;
                end
            endcase
        end
    end

    always @(posedge clk)
    begin
    	if(!rstn)
    	    init_over <= 1'b0;
    	else if(state == STA_RD)// && busy_falling)
    	    init_over <= 1'b1;
    end

endmodule
