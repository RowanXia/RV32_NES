// Applies supported byte-level operand transformations.
// Generates the selected byte-oriented result.


module byteop #(parameter WIDTH=32) (
  input wire [WIDTH-1:0] primary_operand,  // First arithmetic or logical source operand.
  input wire byte_select,  // Provides byte select for this module.
  output wire [WIDTH-1:0] byte_result);  // Provides byte result for this module.

  wire [WIDTH-1:0] orc_b_result_node;
  wire [WIDTH-1:0] rev8_result_node;
  genvar i_node;

  // Apply the same combinational operation to each configured element.
  for (i_node=0;i_node<WIDTH;i_node = i_node + 8) begin : byteloop
    assign orc_b_result_node[i_node+7:i_node] = {8{|primary_operand[i_node+7:i_node]}};
    assign rev8_result_node[WIDTH-i_node-1:WIDTH-i_node-8] = primary_operand[i_node+7:i_node];
  end

  // Select the architectural writeback or execution result source.
  mux2 #(WIDTH) byteresultmux_u(rev8_result_node, orc_b_result_node, byte_select, byte_result);
endmodule
