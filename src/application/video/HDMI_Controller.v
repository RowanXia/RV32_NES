// R6: conservative vertical interpolation; diagnostic mode 3 restores full R5.
// RAM -> index register -> palette register -> four arithmetic stages -> pins.
module HDMI_Controller(
 input hdmi_clk,rst_n,output rd_clk,rd_rst,
 output [15:0] rd_addr,rd_addr10,rd_addr01,rd_addr11,
 input [5:0] rd_data,rd_data10,rd_data01,rd_data11,
 input [1:0] display_size,input video_enable,video_test,
 input [1:0] diagnostic_mode,output reg [5:0] trace_sticky,
 output PIX_CLK,output reg VSYNC_o,HSYNC_o,DATAENABLE_o,
 output reg [7:0] RED_o,GREEN_o,BLUE_o
);
 reg [11:0] hc;reg [10:0] vc;reg [1:0] size_frame;
 reg enable_frame,test_frame;reg [1:0] diagnostic_frame;
 always @(posedge hdmi_clk or negedge rst_n)begin
 if(!rst_n)begin hc<=0;vc<=0;size_frame<=0;enable_frame<=0;test_frame<=0;diagnostic_frame<=0;end
 else begin
 if(hc==2199)begin hc<=0;vc<=(vc==1124)?11'd0:vc+1'b1;end else hc<=hc+1'b1;
 if(hc==0 && vc==0)begin size_frame<=display_size;enable_frame<=video_enable;test_frame<=video_test;diagnostic_frame<=diagnostic_mode;end
 end end
 wire [11:0] left=(size_frame==0)?12'd640:(size_frame==1)?12'd896:12'd1024;
 wire [11:0] right=(size_frame==0)?12'd1664:(size_frame==1)?12'd1408:12'd1280;
 wire [10:0] top=(size_frame==0)?11'd101:(size_frame==1)?11'd341:11'd461;
 wire [10:0] bottom=(size_frame==0)?11'd1061:(size_frame==1)?11'd821:11'd701;
 wire window=(hc>=left && hc<right && vc>=top && vc<bottom);
 wire [11:0] dx=hc-left;wire [10:0] dy=vc-top;
 wire [7:0] x=(size_frame==0)?dx[9:2]:(size_frame==1)?dx[8:1]:dx[7:0];
 wire [7:0] y=(size_frame==0)?dy[9:2]:(size_frame==1)?dy[8:1]:dy[7:0];
 wire [7:0] xn=(x==255)?x:x+1'b1,yn=(y>=239)?8'd239:y+1'b1;
 assign rd_addr=window?{y,x}:16'b0;assign rd_addr10=window?{y,xn}:16'b0;
 assign rd_addr01=window?{yn,x}:16'b0;assign rd_addr11=window?{yn,xn}:16'b0;
 assign rd_clk=hdmi_clk;assign rd_rst=~rst_n;assign PIX_CLK=hdmi_clk;
 wire [1:0] fx_full=(size_frame==0)?dx[1:0]:(size_frame==1)?{dx[0],1'b0}:2'b0;
 // Keep horizontal source-pixel runs intact. The same pipeline, rounding and
 // gain remain active. Mode 3 is the original two-axis interpolation control.
 wire [1:0] fx=(diagnostic_frame==3)?fx_full:2'b0;
 wire [1:0] fy=(size_frame==0)?dy[1:0]:(size_frame==1)?{dy[0],1'b0}:2'b0;
 wire de=(hc>=192 && hc<2112 && vc>=41 && vc<1121);
 wire [23:0] bars=(hc<432)?24'hffffff:(hc<672)?24'hffff00:(hc<912)?24'h00ffff:
 (hc<1152)?24'h00ff00:(hc<1392)?24'hff00ff:(hc<1632)?24'hff0000:(hc<1872)?24'h0000ff:24'h202020;
 reg [5:0] c00,c10,c01,c11;
 wire [23:0] p00,p10,p01,p11;
 NES_Palette pal00(c00,p00);NES_Palette pal10(c10,p10);NES_Palette pal01(c01,p01);NES_Palette pal11(c11,p11);
 reg [23:0] q00,q10,q01,q11;
 reg [3:0] frac_pipe[0:2];reg valid_pipe[0:2];
 reg [2:0] timing_pipe[0:6];reg test_pipe[0:6];reg [23:0] bars_pipe[0:6];
 integer i;
 wire vout /* synthesis syn_keep=1 */;wire [23:0] enhanced;
`ifdef R5_ORIGINAL_ARITH
 image_enhance_bilinear #(.CONTRAST_Q8_8(272),.BRIGHTNESS(0)) u_quality(
 .clk(hdmi_clk),.rst_n(rst_n),.in_valid(valid_pipe[2]),
 .p00_r(q00[23:16]),.p00_g(q00[15:8]),.p00_b(q00[7:0]),
 .p10_r(q10[23:16]),.p10_g(q10[15:8]),.p10_b(q10[7:0]),
 .p01_r(q01[23:16]),.p01_g(q01[15:8]),.p01_b(q01[7:0]),
 .p11_r(q11[23:16]),.p11_g(q11[15:8]),.p11_b(q11[7:0]),
 .frac_x({frac_pipe[2][3:2],6'b0}),.frac_y({frac_pipe[2][1:0],6'b0}),
 .out_valid(vout),.out_r(enhanced[23:16]),.out_g(enhanced[15:8]),.out_b(enhanced[7:0]));
`else
 image_enhance_quarter u_quality(.clk(hdmi_clk),.rst_n(rst_n),.in_valid(valid_pipe[2]),
 .p00(q00),.p10(q10),.p01(q01),.p11(q11),.frac_x(frac_pipe[2][3:2]),.frac_y(frac_pipe[2][1:0]),
 .out_valid(vout),.out_rgb(enhanced));
`endif
 // The reference valid tag is recomputed from the scan coordinates seven
 // clocks earlier, rather than cloning the algorithm-valid shift chain.
 // Display controls commit in vertical blank, far from every image window.
 wire ref_previous_line=(hc<7);
 wire [11:0] ref_h=ref_previous_line?(hc+12'd2193):(hc-12'd7);
 wire [10:0] ref_v=ref_previous_line?((vc==0)?11'd1124:vc-1'b1):vc;
 wire reference_valid=(ref_h>=left && ref_h<right && ref_v>=top && ref_v<bottom && enable_frame);
 wire [23:0] raw_delay[0:3] /* synthesis syn_keep=1 */;
 genvar rs,rb;
 generate for(rs=0;rs<4;rs=rs+1)begin:g_raw_delay
 for(rb=0;rb<24;rb=rb+1)begin:g_bit
 if(rs==0)begin:g_first
 (* syn_preserve=1 *) GTP_DFF_C ff(.CLK(hdmi_clk),.C(~rst_n),.D(q00[rb]),.Q(raw_delay[rs][rb]));
 end else begin:g_next
 (* syn_preserve=1 *) GTP_DFF_C ff(.CLK(hdmi_clk),.C(~rst_n),.D(raw_delay[rs-1][rb]),.Q(raw_delay[rs][rb]));
 end
 end end endgenerate
 reg enable_seen;reg [3:0] monitor_warm;
 reg frame_has_pixels,frame_has_nonzero;
 always @(posedge hdmi_clk or negedge rst_n)begin
 if(!rst_n)begin
 trace_sticky<=0;enable_seen<=0;monitor_warm<=0;frame_has_pixels<=0;frame_has_nonzero<=0;
 end else begin
 if(monitor_warm!=15)monitor_warm<=monitor_warm+1'b1;
 if(video_enable)enable_seen<=1;
 if(enable_seen && !video_enable)trace_sticky[1]<=1;
 if(enable_frame)trace_sticky[0]<=1;
 if(trace_sticky[0] && !enable_frame)trace_sticky[2]<=1;
 if(monitor_warm==15)begin
  if(vout ^ reference_valid)trace_sticky[3]<=1;
  // Every nonblack NES palette entry has a channel >=16, and p00 has
  // weight >=1/16 at all supported phases. Its result cannot be all zero.
  if(reference_valid && raw_delay[3]!=0 && enhanced==0)trace_sticky[4]<=1;
 end
 if(hc==0 && vc==0)begin
  if(frame_has_pixels && !frame_has_nonzero)trace_sticky[5]<=1;
  frame_has_pixels<=0;frame_has_nonzero<=0;
 end else if(reference_valid)begin
  frame_has_pixels<=1;if(enhanced!=0)frame_has_nonzero<=1;
 end
 end end
 always @(posedge hdmi_clk or negedge rst_n)begin
 if(!rst_n)begin
 c00<=0;c10<=0;c01<=0;c11<=0;q00<=0;q10<=0;q01<=0;q11<=0;
 for(i=0;i<3;i=i+1)begin frac_pipe[i]<=0;valid_pipe[i]<=0;end
 for(i=0;i<7;i=i+1)begin timing_pipe[i]<=0;test_pipe[i]<=0;bars_pipe[i]<=0;end
 {HSYNC_o,VSYNC_o,DATAENABLE_o}<=0;{RED_o,GREEN_o,BLUE_o}<=0;
 end else begin
 // This six-bit stage prevents palette logic and DSP input registers from
 // absorbing the entire bank-mux/RAM-to-arithmetic path into one clock.
 c00<=rd_data;c10<=rd_data10;c01<=rd_data01;c11<=rd_data11;
 q00<=p00;q10<=p10;q01<=p01;q11<=p11;
 frac_pipe[0]<={fx,fy};valid_pipe[0]<=window && enable_frame;
 for(i=1;i<3;i=i+1)begin frac_pipe[i]<=frac_pipe[i-1];valid_pipe[i]<=valid_pipe[i-1];end
 timing_pipe[0]<={hc<44,vc<5,de};test_pipe[0]<=test_frame;bars_pipe[0]<=bars;
 for(i=1;i<7;i=i+1)begin timing_pipe[i]<=timing_pipe[i-1];test_pipe[i]<=test_pipe[i-1];bars_pipe[i]<=bars_pipe[i-1];end
 {HSYNC_o,VSYNC_o,DATAENABLE_o}<=timing_pipe[6];
 {RED_o,GREEN_o,BLUE_o}<=timing_pipe[6][0]?(test_pipe[6]?bars_pipe[6]:
 (diagnostic_frame==1?(reference_valid?raw_delay[3]:24'b0):
 (diagnostic_frame==2?(reference_valid?24'hffffff:24'b0):(vout?enhanced:24'b0)))):24'b0;
 end end
endmodule
