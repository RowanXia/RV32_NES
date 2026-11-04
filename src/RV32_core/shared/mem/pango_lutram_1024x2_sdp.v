// Implements a narrow simple-dual-port table using FPGA distributed memory.
// Provides read access and qualified table updates.


module pango_lutram_1024x2_sdp (
  input wire clk, input wire rd_ce, input wire [9:0] rd_addr,  // Destination integer-register index.
  output wire [1:0] rd_data,  // Destination integer-register index.
  input wire wr_ce, input wire [9:0] wr_addr,  // Address operand or target address selection.
  input wire [1:0] wr_data, input wire wr_en  // Data written when the write control is asserted.
);
  reg [9:0] rd_addr_q_node;
  wire [1:0] bank_data_node [0:15];
  // Update registered memory and request state on the clock edge.
  // Clock the rd_addr_q state under the specified reset and enable conditions.
  always @(posedge clk)
    if (rd_ce) rd_addr_q_node <= rd_addr;
  genvar bank_node, bitnum;
  // Elaborate the selected parameter-dependent hardware structure.
  generate for (bank_node=0; bank_node<16; bank_node=bank_node+1) begin: banks
    // Apply the same combinational operation to each configured element.
    for (bitnum=0; bitnum<2; bitnum=bitnum+1) begin: bitslice
      GTP_RAM64X1DP #(.INIT(64'b0)) memory_node (
        .DO(bank_data_node[bank_node][bitnum]), .DI(wr_data[bitnum]),
        .RADDR(rd_addr_q_node[5:0]), .WADDR(wr_addr[5:0]),
        .WCLK(clk), .WE(wr_ce & wr_en & (wr_addr[9:6] == bank_node))
      );
    end
  end endgenerate
  assign rd_data = bank_data_node[rd_addr_q_node[9:6]];
endmodule
