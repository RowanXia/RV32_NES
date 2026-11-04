// Exact R3 bilinear values for 1x/2x/4x phases, without multipliers.
// Four pipeline stages, identical latency and rounding to the R3 gain-272 path.
module image_enhance_quarter(
 input clk,rst_n,in_valid,
 input [23:0] p00,p10,p01,p11,input [1:0] frac_x,frac_y,
 output reg out_valid,output reg [23:0] out_rgb
);
 function [9:0] hmix;
 input [7:0] a,b;input [1:0] f;reg [9:0] aa,bb;
 begin aa={2'b0,a};bb={2'b0,b};case(f)
 0:hmix=aa<<2;1:hmix=(aa<<1)+aa+bb;
 2:hmix=(aa+bb)<<1;3:hmix=aa+(bb<<1)+bb;
 endcase end endfunction
 function [11:0] vmix;
 input [9:0] a,b;input [1:0] f;reg [11:0] aa,bb;
 begin aa={2'b0,a};bb={2'b0,b};case(f)
 0:vmix=aa<<2;1:vmix=(aa<<1)+aa+bb;
 2:vmix=(aa+bb)<<1;3:vmix=aa+(bb<<1)+bb;
 endcase end endfunction
 function [7:0] gain;
 input [7:0] p;reg [8:0] v;
 begin v={1'b0,p}+(({1'b0,p}+9'd8)>>4);gain=(v>255)?8'd255:v[7:0];end
 endfunction
 reg [9:0] hr0,hr1,hg0,hg1,hb0,hb1;
 reg [11:0] sr,sg,sb;reg [23:0] rounded;
 reg [1:0] fy;reg v1,v2,v3;
 always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
 hr0<=0;hr1<=0;hg0<=0;hg1<=0;hb0<=0;hb1<=0;
 sr<=0;sg<=0;sb<=0;rounded<=0;fy<=0;v1<=0;v2<=0;v3<=0;out_valid<=0;out_rgb<=0;
 end else begin
 v1<=in_valid;v2<=v1;v3<=v2;out_valid<=v3;fy<=frac_y;
 hr0<=hmix(p00[23:16],p10[23:16],frac_x);hr1<=hmix(p01[23:16],p11[23:16],frac_x);
 hg0<=hmix(p00[15:8],p10[15:8],frac_x);hg1<=hmix(p01[15:8],p11[15:8],frac_x);
 hb0<=hmix(p00[7:0],p10[7:0],frac_x);hb1<=hmix(p01[7:0],p11[7:0],frac_x);
 sr<=vmix(hr0,hr1,fy)+12'd8;sg<=vmix(hg0,hg1,fy)+12'd8;sb<=vmix(hb0,hb1,fy)+12'd8;
 rounded<={sr[11:4],sg[11:4],sb[11:4]};
 out_rgb<={gain(rounded[23:16]),gain(rounded[15:8]),gain(rounded[7:0])};
 end end
endmodule
