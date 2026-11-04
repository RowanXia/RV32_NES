// Computes a parameterized-width arithmetic sum.
// Provides a reusable combinational datapath element.


module adder #(parameter WIDTH=8) (
  input wire [WIDTH-1:0] generic_input_a,  // First input data word for the combinational operation.
  input wire [WIDTH-1:0] generic_input_b,  // Second input data word for the combinational operation.
  output wire [WIDTH-1:0] generic_result  // Combinational result of this parameterized utility.
);

  // Return the WIDTH-bit sum of the two input operands.
  assign generic_result = generic_input_a + generic_input_b;
endmodule
