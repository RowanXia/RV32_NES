// Four-bank parity framebuffer. Same 65536x6 capacity as the baseline.
// Four clamped neighbors share banks only when their addresses are identical.
module image_quad_framebuffer(
 input wr_clk,wr_rst,wr_en,input [15:0] wr_addr,input [5:0] wr_data,
 input rd_clk,rd_rst,input [15:0] addr00,addr10,addr01,addr11,
 output [5:0] data00,data10,data01,data11
);
wire [5:0] bank_data[0:3];
reg [1:0] sel00,sel10,sel01,sel11;
always @(posedge rd_clk or posedge rd_rst)begin
 if(rd_rst)begin sel00<=0;sel10<=0;sel01<=0;sel11<=0;end
 else begin sel00<={addr00[8],addr00[0]};sel10<={addr10[8],addr10[0]};sel01<={addr01[8],addr01[0]};sel11<={addr11[8],addr11[0]};end
end
assign data00=bank_data[sel00];assign data10=bank_data[sel10];
assign data01=bank_data[sel01];assign data11=bank_data[sel11];
genvar b;
generate for(b=0;b<4;b=b+1)begin:g_bank
 wire [15:0] request=({addr00[8],addr00[0]}==b)?addr00:
                       ({addr10[8],addr10[0]}==b)?addr10:
                       ({addr01[8],addr01[0]}==b)?addr01:addr11;
 wire [13:0] compact_read={request[15:9],request[7:1]};
 wire [13:0] compact_write={wr_addr[15:9],wr_addr[7:1]};
 wire we=wr_en && ({wr_addr[8],wr_addr[0]}==b);
`ifdef IMAGE_RAM_MODEL
 reg [5:0] mem[0:16383];reg [5:0] q;
 always @(posedge wr_clk)if(we)mem[compact_write]<=wr_data;
 always @(posedge rd_clk)q<=mem[compact_read];
 assign bank_data[b]=q;
`else
 ipm2l_dpram_v1_9_Display_Buffer #(
 .c_A_ADDR_WIDTH(14),.c_B_ADDR_WIDTH(14),.c_A_DATA_WIDTH(6),.c_B_DATA_WIDTH(6),
 .c_A_BE_WIDTH(1),.c_B_BE_WIDTH(1),.c_INIT_FILE("NONE")) u_ram(
 .a_addr(compact_write),.a_wr_data(wr_data),.a_rd_data(),.a_wr_en(we),
 .a_clk(wr_clk),.a_clk_en(1'b1),.a_rst(wr_rst),.a_wr_byte_en(1'b1),.a_rd_oce(1'b0),.a_addr_strobe(1'b0),
 .b_addr(compact_read),.b_wr_data(6'b0),.b_rd_data(bank_data[b]),.b_wr_en(1'b0),
 .b_clk(rd_clk),.b_clk_en(1'b1),.b_rst(rd_rst),.b_wr_byte_en(1'b1),.b_rd_oce(1'b0),.b_addr_strobe(1'b0));
`endif
end endgenerate
endmodule
