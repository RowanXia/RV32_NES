// These are FPGA-side observations; they do not sense the PCB or MS7210 pins.
module nes_audio_led_diag #(parameter HB_HALF_CYCLES=24576000)(
 input clk,input rst_n,input bclk,input ws,input sd,input tone_active,
 output heartbeat,output reg bclk_seen,output reg ws_seen,output reg sd_seen
);
 reg [24:0] heartbeat_count;
 reg heartbeat_r,bclk_q,ws_q,sd_q;
 assign heartbeat=heartbeat_r;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   heartbeat_count<=0;heartbeat_r<=0;
   bclk_q<=0;ws_q<=0;sd_q<=0;bclk_seen<=0;ws_seen<=0;sd_seen<=0;
  end else begin
   if(heartbeat_count==HB_HALF_CYCLES-1) begin heartbeat_count<=0;heartbeat_r<=~heartbeat_r;end
   else heartbeat_count<=heartbeat_count+1'b1;
   bclk_q<=bclk;ws_q<=ws;sd_q<=sd;
   if(bclk!=bclk_q) bclk_seen<=1;
   if(ws!=ws_q) ws_seen<=1;
   if(tone_active && sd!=sd_q) sd_seen<=1;
  end
 end
endmodule
