// Reusable image quality pipeline: bilinear resampling followed by RGB enhancement.
module image_quality_resource_top #(
 parameter integer CONTRAST_Q8_8=272, parameter integer BRIGHTNESS=0
)(
 input wire clk,input wire rst_n,input wire in_valid,
 input wire [7:0] p00_r,p00_g,p00_b,p10_r,p10_g,p10_b,p01_r,p01_g,p01_b,p11_r,p11_g,p11_b,
 input wire [7:0] frac_x,frac_y,
 output wire out_valid,output wire [7:0] out_r,out_g,out_b
);
wire v_i; wire [7:0] r_i,g_i,b_i;
bilinear_interpolator_rgb u_interp(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.p00_r(p00_r),.p00_g(p00_g),.p00_b(p00_b),.p10_r(p10_r),.p10_g(p10_g),.p10_b(p10_b),.p01_r(p01_r),.p01_g(p01_g),.p01_b(p01_b),.p11_r(p11_r),.p11_g(p11_g),.p11_b(p11_b),.frac_x(frac_x),.frac_y(frac_y),.out_valid(v_i),.out_r(r_i),.out_g(g_i),.out_b(b_i));
image_enhance_rgb #(.CONTRAST_Q8_8(CONTRAST_Q8_8),.BRIGHTNESS(BRIGHTNESS)) u_enh(.clk(clk),.rst_n(rst_n),.in_valid(v_i),.in_r(r_i),.in_g(g_i),.in_b(b_i),.out_valid(out_valid),.out_r(out_r),.out_g(out_g),.out_b(out_b));
endmodule
