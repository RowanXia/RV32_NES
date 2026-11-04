// RGB888 bilinear interpolation, Q0.8 fractions. Latency: 3 clocks.
module bilinear_interpolator_rgb(
 input wire clk, rst_n, in_valid,
 input wire [7:0] p00_r,p00_g,p00_b,p10_r,p10_g,p10_b,
 input wire [7:0] p01_r,p01_g,p01_b,p11_r,p11_g,p11_b,
 input wire [7:0] frac_x,frac_y,
 output reg out_valid, output reg [7:0] out_r,out_g,out_b
);
wire [8:0] wx0=9'd256-{1'b0,frac_x};
reg [8:0] wy0,wy1;
reg v1,v2;
reg [15:0] h0_r,h1_r;
reg [23:0] sum_r;
reg [15:0] h0_g,h1_g;
reg [23:0] sum_g;
reg [15:0] h0_b,h1_b;
reg [23:0] sum_b;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  v1<=0; v2<=0; out_valid<=0; wy0<=0; wy1<=0; out_r<=0;out_g<=0;out_b<=0;
  h0_r<=0;h1_r<=0;sum_r<=0;
  h0_g<=0;h1_g<=0;sum_g<=0;
  h0_b<=0;h1_b<=0;sum_b<=0;
 end else begin
  v1<=in_valid;v2<=v1;out_valid<=v2;
  wy0<=9'd256-{1'b0,frac_y};wy1<={1'b0,frac_y};
  h0_r<=p00_r*wx0+p10_r*{1'b0,frac_x};
  h1_r<=p01_r*wx0+p11_r*{1'b0,frac_x};
  sum_r<=h0_r*wy0+h1_r*wy1+24'd32768;
  out_r<=sum_r[23:16];
  h0_g<=p00_g*wx0+p10_g*{1'b0,frac_x};
  h1_g<=p01_g*wx0+p11_g*{1'b0,frac_x};
  sum_g<=h0_g*wy0+h1_g*wy1+24'd32768;
  out_g<=sum_g[23:16];
  h0_b<=p00_b*wx0+p10_b*{1'b0,frac_x};
  h1_b<=p01_b*wx0+p11_b*{1'b0,frac_x};
  sum_b<=h0_b*wy0+h1_b*wy1+24'd32768;
  out_b<=sum_b[23:16];
 end
end
endmodule
