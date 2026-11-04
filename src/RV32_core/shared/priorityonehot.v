// Selects one active bit according to the configured priority.
// Encodes multiple requests as a single one-hot grant.


module priorityonehot #(parameter N = 8) (
  input wire [N-1:0] generic_input_a,  // First input data word for the combinational operation.
  output wire [N-1:0] generic_result  // Combinational result of this parameterized utility.
);

  genvar i_node;

  assign generic_result[0] = generic_input_a[0];
  // Apply the same combinational operation to each configured element.
  for (i_node=1; i_node<N; i_node = i_node + 1) begin : poh
    assign generic_result[i_node] = generic_input_a[i_node] & ~|generic_input_a[i_node-1:0];
  end

endmodule
