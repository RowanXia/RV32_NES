// Asynchronously assert reset and release it after two local clock edges.
// Primitive instance names are also referenced by board_compat.fdc.
module nes_reset_sync(input clk,arst_n,output rst_n);
 wire sync_meta;
 GTP_DFF_C meta_ff(.CLK(clk),.C(~arst_n),.D(1'b1),.Q(sync_meta));
 GTP_DFF_C sync_ff(.CLK(clk),.C(~arst_n),.D(sync_meta),.Q(rst_n));
endmodule

// Hold each payload throughout a request/acknowledge round trip.
// Destination capture follows two request stages and one settling cycle.
module nes_cdc_mailbox #(parameter WIDTH=16)(
 input src_clk,src_rst_n,input [WIDTH-1:0] src_data,
 input dst_clk,dst_rst_n,output wire [WIDTH-1:0] dst_data);
 wire [WIDTH-1:0] held_data;
 reg req,ack,ack_sync,req_sync,req_delay;
 wire ack_meta,req_meta;
 GTP_DFF_C ack_meta_ff(.CLK(src_clk),.C(~src_rst_n),.D(ack),.Q(ack_meta));
 GTP_DFF_C req_meta_ff(.CLK(dst_clk),.C(~dst_rst_n),.D(req),.Q(req_meta));
 genvar i;
 generate for(i=0;i<WIDTH;i=i+1)begin:g_bits
  GTP_DFF_CE held_ff(.CLK(src_clk),.C(~src_rst_n),.CE(ack_sync==req),.D(src_data[i]),.Q(held_data[i]));
  GTP_DFF_CE dst_ff(.CLK(dst_clk),.C(~dst_rst_n),.CE(req_delay!=ack),.D(held_data[i]),.Q(dst_data[i]));
 end endgenerate
 // The two processes own disjoint registers in their respective domains.
 always @(posedge dst_clk or negedge dst_rst_n)
  if(!dst_rst_n)begin req_sync<=0;req_delay<=0;ack<=0;end
  else begin req_sync<=req_meta;req_delay<=req_sync;if(req_delay!=ack)ack<=req_delay;end
 always @(posedge src_clk or negedge src_rst_n)
  if(!src_rst_n) begin req<=0;ack_sync<=0;end
  else begin ack_sync<=ack_meta;if(ack_sync==req)req<=~req;end
endmodule
