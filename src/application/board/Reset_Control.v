// Assert board reset on external reset or PLL unlock.
// Release only after two synchronization stages and the debounce interval.
module Reset_Control #(parameter integer CLK_FREQ=42880000,parameter integer DEBOUNCE_TIME=10)(
 input clk,RST_in,pll_locked,output rst_out,rst_out_n);
 localparam integer MAX_COUNT=CLK_FREQ/1000*DEBOUNCE_TIME;
 localparam integer COUNTER_WIDTH=(MAX_COUNT<2)?1:$clog2(MAX_COUNT);
 reg [COUNTER_WIDTH-1:0] counter;
 reg sync_meta,sync_q;
 wire arst_n=RST_in & pll_locked;
 always @(posedge clk or negedge arst_n)
  if(!arst_n) begin sync_meta<=0;sync_q<=0;end
  else begin sync_meta<=1;sync_q<=sync_meta;end
 reg released;
 always @(posedge clk or negedge arst_n)
  if(!arst_n) begin counter<=0;released<=0;end
  else if(!sync_q) begin counter<=0;released<=0;end
  else if(!released) begin
   if(counter==MAX_COUNT-1)released<=1;
   else counter<=counter+1'b1;
  end
 assign rst_out_n=released;assign rst_out=~released;
endmodule
