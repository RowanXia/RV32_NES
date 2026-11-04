// Reorders bits for supported bit-reversal operations.
// Produces a combinationally rearranged result.


module bitreverse #(parameter WIDTH=32) (
  input wire [WIDTH-1:0] primary_operand,  // First arithmetic or logical source operand.
  output wire [WIDTH-1:0] rev_a);  // Provides rev a for this module.

  genvar i_node;
  // Apply the same combinational operation to each configured element.
  for (i_node=0; i_node<WIDTH;i_node = i_node + 1) begin : loop_node
    assign rev_a[WIDTH-i_node-1] = primary_operand[i_node];
  end
endmodule
