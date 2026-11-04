// Compares branch operands for equality and signed or unsigned ordering.
// Produces condition flags used by control-flow decisions.


module branch_compare #(parameter WIDTH=64) (
  input wire [WIDTH-1:0] generic_input_a,  // First input data word for the combinational operation.
  input wire [WIDTH-1:0] generic_input_b,  // Second input data word for the combinational operation.
  input wire sgnd,  // Selects signed versus unsigned ordering for branch comparison.
  output wire [1:0] flags);  // Comparison flags containing equality and less-than results.

  wire operands_equal_node;
  wire signed_mode_less_node;         
  wire [WIDTH-1:0] adjusted_operand_a_node;
  wire [WIDTH-1:0] adjusted_operand_b_node; 

  
  // Compare register operands for equality before evaluating ordering.
  assign operands_equal_node = (generic_input_a == generic_input_b);            

  
  // Toggle the sign bit for signed ordering while retaining unsigned comparator logic.
  assign adjusted_operand_a_node = {generic_input_a[WIDTH-1] ^ sgnd, generic_input_a[WIDTH-2:0]};
  assign adjusted_operand_b_node = {generic_input_b[WIDTH-1] ^ sgnd, generic_input_b[WIDTH-2:0]};

  // Return the equality and magnitude flags used by branch condition decoding.
  assign signed_mode_less_node = (adjusted_operand_a_node < adjusted_operand_b_node); 
  assign flags = {operands_equal_node, signed_mode_less_node};
endmodule
