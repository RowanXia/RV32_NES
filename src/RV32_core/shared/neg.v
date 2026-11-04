// Computes arithmetic negation of a data word.
// Produces the two-complement negative value.


module neg #(parameter WIDTH = 8) (
  input wire [WIDTH-1:0] generic_input_a,  // First input data word for the combinational operation.
  output wire [WIDTH-1:0] generic_result);  // Combinational result of this parameterized utility.

  // Compute two-complement negation by inverting the input and adding one.
  assign generic_result = ~generic_input_a + 1;
endmodule
