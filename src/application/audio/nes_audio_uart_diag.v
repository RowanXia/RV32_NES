// Read-only diagnostic UART. Enabled by KEY4+KEY1; no CPU firmware changes.
// Line: "AUD4 " + 13 register bytes and one flag byte, hex, then CR/LF.
module nes_audio_uart_diag #(
 parameter CLOCK_HZ=42880000,parameter BAUD=115200,
 parameter INTERVAL_CYCLES=42880000
)(input clk,input rst_n,input enable,input [103:0] regs,input [7:0] flags,
  output tx);
 localparam BIT_CYCLES=CLOCK_HZ/BAUD;
 reg [25:0] wait_count;
 reg [15:0] baud_count;
 reg [9:0] shift_reg;
 reg [3:0] bits_left;
 reg [5:0] char_index;
 reg active;
 reg [111:0] snapshot;
 wire [7:0] payload_byte=snapshot[((char_index-5)>>1)*8 +: 8];
 wire [3:0] nibble=char_index[0] ? payload_byte[7:4] : payload_byte[3:0];
 function [7:0] hexchar;
 input [3:0] n;
 begin hexchar=n<10 ? 8'd48+n : 8'd65+n-10;end
 endfunction
 reg [7:0] next_char;
 always @* begin
  case(char_index)
   0:next_char="A";1:next_char="U";2:next_char="D";3:next_char="4";4:next_char=" ";
   33:next_char=8'h0d;34:next_char=8'h0a;
   default:next_char=hexchar(nibble);
  endcase
 end
 assign tx=bits_left!=0 ? shift_reg[0] : 1'b1;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   wait_count<=0;baud_count<=0;shift_reg<=10'h3ff;bits_left<=0;
   char_index<=0;active<=0;snapshot<=0;
  end else if(!enable) begin
   wait_count<=0;baud_count<=0;bits_left<=0;active<=0;char_index<=0;
  end else if(!active) begin
   if(wait_count==0) begin snapshot<={flags,regs};active<=1;char_index<=0;end
   else wait_count<=wait_count-1'b1;
  end else if(bits_left==0) begin
   shift_reg<={1'b1,next_char,1'b0};bits_left<=10;baud_count<=BIT_CYCLES-1;
  end else if(baud_count!=0) baud_count<=baud_count-1'b1;
  else begin
   shift_reg<={1'b1,shift_reg[9:1]};bits_left<=bits_left-1'b1;baud_count<=BIT_CYCLES-1;
   if(bits_left==1) begin
    if(char_index==34) begin active<=0;wait_count<=INTERVAL_CYCLES-1;end
    else char_index<=char_index+1'b1;
   end
  end
 end
endmodule
