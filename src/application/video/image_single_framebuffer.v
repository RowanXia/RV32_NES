// Four 16K-by-6 banks provide one 64K-by-6 dual-clock framebuffer.
module image_single_framebuffer(
 input wr_clk,wr_rst,wr_en,input [15:0] wr_addr,input [5:0] wr_data,
 input rd_clk,rd_rst,input [15:0] rd_addr,output [5:0] rd_data
);
 wire [5:0] bank_data[0:3];reg [1:0] read_bank_q;
 genvar b;
 generate for(b=0;b<4;b=b+1)begin:g_bank
  wire we=wr_en && wr_addr[15:14]==b;
`ifdef IMAGE_RAM_MODEL
  reg [5:0] mem[0:16383];reg [5:0] data_q;
  always @(posedge wr_clk)if(we)mem[wr_addr[13:0]]<=wr_data;
  always @(posedge rd_clk)data_q<=mem[rd_addr[13:0]];
  assign bank_data[b]=data_q;
`else
  ipm2l_dpram_v1_9_Display_Buffer #(
   .c_A_ADDR_WIDTH(14),.c_B_ADDR_WIDTH(14),.c_A_DATA_WIDTH(6),.c_B_DATA_WIDTH(6),
   .c_A_BE_WIDTH(1),.c_B_BE_WIDTH(1),.c_INIT_FILE("NONE")) pixel_bank_u(
   .a_addr(wr_addr[13:0]),.a_wr_data(wr_data),.a_rd_data(),.a_wr_en(we),
   .a_clk(wr_clk),.a_clk_en(1'b1),.a_rst(wr_rst),.a_wr_byte_en(1'b1),.a_rd_oce(1'b0),.a_addr_strobe(1'b0),
   .b_addr(rd_addr[13:0]),.b_wr_data(6'b0),.b_rd_data(bank_data[b]),.b_wr_en(1'b0),
   .b_clk(rd_clk),.b_clk_en(1'b1),.b_rst(rd_rst),.b_wr_byte_en(1'b1),.b_rd_oce(1'b0),.b_addr_strobe(1'b0));
`endif
 end endgenerate

 // Delay bank selection by the same cycle as each bank's registered read.
 // This process stays outside g_bank and has exactly one register driver.
 always @(posedge rd_clk or posedge rd_rst)
  if(rd_rst)read_bank_q<=0;else read_bank_q<=rd_addr[15:14];
 assign rd_data=bank_data[read_bank_q];
endmodule
