`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Myminieye
// Engineer: Nill
// 
// Create Date: 2019-09-16 19:46
// Design Name: 
// Module Name: hdmi_tx_register_sequence
// Project Name: hdmi_tx
// Target Devices: Pg2l100H  
// Tool Versions: 
// Description:  
// 
// Dependencies: 
// Revision: v1.0
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define UD #1
module hdmi_tx_config(
    input       clk,
    input       rst_n,
    
    output      init_over_rx,
    output      init_over_tx,
    output      iic_scl,
    inout       iic_sda,
    output      audio_config_ok,
    output      nack_seen,
    output [103:0] audio_debug_regs
);
    reg rstn_temp1,rstn_temp2;
    reg rstn;
    always @(posedge clk or negedge rst_n)
    begin
    	if(!rst_n)
    	    rstn_temp1 <= 1'b0;
    	else
    	    rstn_temp1 <= rst_n;
    end
    
    always @(posedge clk)
    begin
    	rstn_temp2 <= rstn_temp1;
    	rstn <= rstn_temp2;
    end
    
    wire   [7:0] device_id_tx;
    wire         iic_trig_tx ;
    wire         w_r_tx      ;
    wire  [15:0] addr_tx     ;
    wire  [ 7:0] data_in_tx  ;
    wire         busy_tx     ;
    wire  [ 7:0] data_out_tx ;
    wire         byte_over_tx;
    
    wire   [7:0] device_id   ;
    wire         iic_trig    ;
    wire         w_r         ;
    wire  [15:0] addr        ;
    wire  [ 7:0] data_in     ;
    wire         busy        ;
    wire  [ 7:0] data_out    ;
    wire         byte_over   ;
	
	assign init_over_rx = rstn;
    
    hdmi_tx_register_sequence transmitter_sequence_u(
        .clk             (  clk           ),//input               
        .rstn            (  init_over_rx  ),//input               
                              
        .init_over       (  init_over_tx  ),//output reg    发送端已初始化完成       
        .device_id       (                ),//output        [7:0] 
        .iic_trig        (  iic_trig_tx   ),//output reg          
        .w_r             (  w_r_tx        ),//output reg          
        .addr            (  addr_tx       ),//output reg   [15:0] 
        .data_in         (  data_in_tx    ),//output reg   [ 7:0] 
        .busy            (  busy_tx       ),//input               
        .data_out        (  data_out_tx   ),//input        [ 7:0] 
        .byte_over       (  byte_over_tx  ), //input
        .audio_config_ok ( audio_config_ok ),
        .audio_debug_regs( audio_debug_regs )
    );

    // MS7200地址：0x56，MS7210地址：0xB2，
    assign device_id = 8'hB2;//device_id_tx : device_id_rx;
    assign iic_trig = iic_trig_tx;
    assign w_r = w_r_tx;
    assign addr = addr_tx;
    assign data_in = data_in_tx;
    assign busy_tx = busy;
    assign data_out_tx = data_out;
    assign byte_over_tx = byte_over;
    
    assign busy_rx = busy;
    assign data_out_rx = data_out;
    assign byte_over_rx = byte_over;

    wire         sda_in;
    wire         sda_out;
    wire         sda_out_en;  
    hdmi_i2c_master #(
        .CLK_FRE        (  27'd42_880_000  ),//parameter            CLK_FRE   = 27'd50_000_000,//system clock frequency
        .IIC_FREQ       (  20'd400_000     ),//parameter            IIC_FREQ  = 20'd400_000,   //I2c clock frequency
        .T_WR           (  10'd1           ),//parameter            T_WR      = 10'd5,         //I2c transmit delay ms
        .ADDR_BYTE      (  2'd2            ),//parameter            ADDR_BYTE = 2'd1,          //I2C addr byte number
        .LEN_WIDTH      (  8'd3            ),//parameter            LEN_WIDTH = 8'd3,          //I2C transmit byte width
        .DATA_BYTE      (  2'd1            ) //parameter            DATA_BYTE = 2'd1           //I2C data byte number
    )hdmi_i2c_master(                       
        .clk            (  clk             ),//input                clk,
        .rstn           (  rstn            ),//input                rstn,
        .device_id      (  device_id       ),//input                device_id,
        .pluse          (  iic_trig        ),//input                pluse,                     //I2C transmit trigger
        .w_r            (  w_r             ),//input                w_r,                       //I2C transmit direction 1:send  0:receive
        .byte_len       (  4'd1            ),//input  [LEN_WIDTH:0] byte_len,                  //I2C transmit data byte length of once trigger
                   
        .addr           (  addr            ),//input  [7:0]         addr,                      //I2C transmit addr
        .data_in        (  data_in         ),//input  [7:0]         data_in,                   //I2C send data
                     
        .busy           (  busy            ),//output reg           busy=0,                    //I2C bus status
        
        .byte_over      (  byte_over       ),//output reg           byte_over=0,               //I2C byte transmit over flag               
        .data_out       (  data_out        ),//output reg[7:0]      data_out,                  //I2C receive data
                                           
        .scl            (  iic_scl         ),//output               scl,
        .sda_in         (  sda_in          ),//input                sda_in,
        .sda_out        (  sda_out         ),//output   reg         sda_out=1'b1,
        .sda_out_en     (  sda_out_en      ), //output
        .nack_seen      (  nack_seen       ),
        .monitor_enable( init_over_tx )
    );
    
    assign iic_sda = sda_out_en ? sda_out : 1'bz;
    assign sda_in = iic_sda;
    
endmodule
