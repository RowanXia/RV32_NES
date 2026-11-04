// Configurable per-pixel RGB enhancement. One pixel per cycle, one-cycle latency.
module image_enhance_rgb #(
    parameter integer CONTRAST_Q8_8 = 256,  // 1.0 = 256
    parameter integer BRIGHTNESS = 0,       // signed 8-bit offset
    parameter integer SATURATION = 255       // output clamp maximum
)(
    input wire clk, input wire rst_n, input wire in_valid,
    input wire [7:0] in_r, input wire [7:0] in_g, input wire [7:0] in_b,
    output reg out_valid, output reg [7:0] out_r, output reg [7:0] out_g, output reg [7:0] out_b
);
function [7:0] clamp8;
 input integer v;
 begin if (v < 0) clamp8 = 8'd0; else if (v > SATURATION) clamp8 = SATURATION[7:0]; else clamp8 = v[7:0]; end
endfunction
integer rr, gg, bb;
always @(posedge clk or negedge rst_n) begin
 if (!rst_n) begin out_valid<=1'b0; out_r<=0; out_g<=0; out_b<=0; end
 else begin
  out_valid <= in_valid;
  if (in_valid) begin
   rr = (((in_r * CONTRAST_Q8_8) + 128) >>> 8) + BRIGHTNESS;
   gg = (((in_g * CONTRAST_Q8_8) + 128) >>> 8) + BRIGHTNESS;
   bb = (((in_b * CONTRAST_Q8_8) + 128) >>> 8) + BRIGHTNESS;
   out_r <= clamp8(rr); out_g <= clamp8(gg); out_b <= clamp8(bb);
  end
 end
end
endmodule
