`timescale 1ns/1ps
// Serve AHB reads from a single-sector cache filled by the SPI card reader.
// Hold sector payloads through the request/completion toggle handshake.
module SDCARD_Controller #(
 parameter SIM_INIT=0,
 parameter SYSTEM_CLOCK_100MHZ=1'b0
)(
 input HCLK,HRESETn,HSEL,input [31:0] HADDR,HWDATA,
 input HWRITE,input [1:0] HTRANS,input [2:0] HSIZE,input HREADY,
 output [31:0] HRDATA,output HREADYOUT,HRESP,
 output init_end,sd_rd_busy,output CLK,MOSI,input MISO,output CS_N);
 reg sd_clk;
 reg [7:0] divider;
 wire init_raw;
 wire init_meta;reg init_sync;
 GTP_DFF_C init_meta_ff(.CLK(HCLK),.C(~HRESETn),.D(init_raw),.Q(init_meta));
 always @(posedge HCLK or negedge HRESETn)
  if(!HRESETn)begin init_sync<=0;end
  else begin init_sync<=init_meta;end
 assign init_end=init_sync;
 // Apply the initialization or read divisor when the current half-cycle ends.
 always @(posedge HCLK or negedge HRESETn)
  if(!HRESETn)begin sd_clk<=0;divider<=0;end
 else if(divider >= (init_sync ?
                     (SYSTEM_CLOCK_100MHZ ? 8'd4 : 8'd1) :
                     (SYSTEM_CLOCK_100MHZ ? 8'd124 : 8'd99))) begin
   divider<=0;sd_clk<=~sd_clk;
 end
  else divider<=divider+1'b1;
 wire sd_reset_n,read_reset_n;
 nes_reset_sync sd_reset(.clk(sd_clk),.arst_n(HRESETn),.rst_n(sd_reset_n));
 nes_reset_sync read_reset(.clk(sd_clk),.arst_n(sd_reset_n & init_raw),.rst_n(read_reset_n));
 wire init_mosi,init_cs,read_mosi,read_cs,read_end;
 generate if(SIM_INIT)begin:g_sim_init
 reg sim_init=0;
 initial begin #500000;sim_init=1;end
 assign init_raw=sim_init;assign init_mosi=1'b1;assign init_cs=1'b1;
 end else begin:g_real_init
 SD_Init sd_init(.sys_clk(sd_clk),.sys_clk_shift(~sd_clk),.sys_rst_n(sd_reset_n),
 .miso(MISO),.mosi(init_mosi),.cs_n(init_cs),.init_end(init_raw));
 end endgenerate
 assign CLK=~sd_clk;
 assign MOSI=init_raw ? read_mosi : init_mosi;
 assign CS_N=init_raw ? read_cs : init_cs;
 reg request;
 wire request_meta;reg request_sync,request_seen;
 GTP_DFF_C request_meta_ff(.CLK(sd_clk),.C(~read_reset_n),.D(request),.Q(request_meta));
 reg complete;
 wire complete_meta;reg complete_sync;
 GTP_DFF_C complete_meta_ff(.CLK(HCLK),.C(~HRESETn),.D(complete),.Q(complete_meta));
 reg [20:0] requested_sector;
 wire start_read=(request_sync!=request_seen) && read_reset_n;
 wire [20:0] sd_sector;
 reg read_start_q;
 genvar bit_index;
 generate for(bit_index=0;bit_index<21;bit_index=bit_index+1)begin:g_sector
  GTP_DFF_CE payload_ff(.CLK(sd_clk),.C(~read_reset_n),.CE(start_read),
   .D(requested_sector[bit_index]),.Q(sd_sector[bit_index]));
 end endgenerate
 always @(posedge sd_clk or negedge read_reset_n)
  if(!read_reset_n)begin request_sync<=0;request_seen<=0;complete<=0;read_start_q<=0;end
  else begin
   read_start_q<=start_read;
   request_sync<=request_meta;
   if(start_read)request_seen<=request_sync;
   if(read_end)complete<=request_seen;
  end
 always @(posedge HCLK or negedge HRESETn)
  if(!HRESETn)begin complete_sync<=0;end
  else begin complete_sync<=complete_meta;end
 wire write_buffer;
 wire [31:0] sector_word;
 wire [6:0] sector_word_addr;
 SD_Read sd_read(.sys_clk(sd_clk),.sys_clk_shift(~sd_clk),.sys_rst_n(read_reset_n),
  .miso(MISO),.rd_en(read_start_q),.rd_addr({11'b0,sd_sector}),
  .mosi(read_mosi),.cs_n(read_cs),.rd_busy(sd_rd_busy),.sd_read_end(read_end),
  .rd_data_en(write_buffer),.rd_data(sector_word),.sd_rd_addr(sector_word_addr));
 reg [2:0] state;
 localparam IDLE=0,WAIT_INIT=1,WAIT_SECTOR=2,READ1=3,READ2=4,DONE=5,ERR1=6,ERR2=7;
 reg [31:0] address_q;
 reg [20:0] cached_sector;
 reg cache_valid;
 reg [25:0] watchdog;
 wire accept=HSEL && HTRANS[1] && HREADY;
 wire bad=HWRITE || HSIZE>2 || (HSIZE==1 && HADDR[0]) || (HSIZE==2 && |HADDR[1:0]);
 assign HREADYOUT=(state==IDLE)||(state==DONE)||(state==ERR2);
 assign HRESP=(state==ERR1)||(state==ERR2);
 wire [31:0] buffer_data;
 reg [31:0] rdata_q;
 assign HRDATA=rdata_q;
 SDCARD_RDBuffer SDCARD_read_buffer(
  .wr_data(sector_word),.wr_addr({2'b0,sector_word_addr}),.wr_en(write_buffer),
  .wr_clk(sd_clk),.wr_rst(!sd_reset_n),.rd_addr({2'b0,address_q[8:2]}),
  .rd_data(buffer_data),.rd_clk(HCLK),.rd_rst(!HRESETn));
 always @(posedge HCLK or negedge HRESETn)
  if(!HRESETn)begin state<=IDLE;address_q<=0;cached_sector<=0;cache_valid<=0;
   request<=0;requested_sector<=0;rdata_q<=0;watchdog<=0;end
  else begin
   if(state==WAIT_INIT || state==WAIT_SECTOR)watchdog<=watchdog+1'b1;
   else watchdog<=0;
   case(state)
    IDLE,DONE,ERR2:if(HREADY)begin
     if(accept)begin address_q<=HADDR;state<=bad?ERR1:WAIT_INIT;end
     else state<=IDLE;
    end
    WAIT_INIT:if(init_sync)begin
     if(cache_valid && cached_sector==address_q[29:9])state<=READ1;
     else begin requested_sector<=address_q[29:9];request<=~request;state<=WAIT_SECTOR;end
    end else if(&watchdog)state<=ERR1;
    WAIT_SECTOR:if(complete_sync==request)begin
     cached_sector<=requested_sector;cache_valid<=1;state<=READ1;
    end else if(&watchdog)state<=ERR1;
    READ1:state<=READ2;
    READ2:begin rdata_q<=buffer_data;state<=DONE;end
    ERR1:state<=ERR2;
    default:state<=IDLE;
   endcase
  end
endmodule
