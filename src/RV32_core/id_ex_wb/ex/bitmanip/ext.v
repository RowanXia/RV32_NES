// Expands selected narrow fields to the processor data width.
// Applies sign or zero extension as controlled by the operation.


module ext #(parameter WIDTH = 32) (
  input wire [15:0] primary_operand,  // First arithmetic or logical source operand.
  input wire [1:0] ext_select,  // Provides ext select for this module.
  output wire [WIDTH-1:0] ext_result);  // Provides ext result for this module.

  wire [WIDTH-1:0] sexth_result_node;
  wire [WIDTH-1:0] zexth_result_node;
  wire [WIDTH-1:0] sextb_result_node;

  assign sextb_result_node = {{(WIDTH-8){primary_operand[7]}},primary_operand[7:0]};
  assign sexth_result_node = {{(WIDTH-16){primary_operand[15]}},primary_operand[15:0]};
  assign zexth_result_node = {{(WIDTH-16){1'b0}},primary_operand[15:0]};

  // Select the appropriate datapath value from the available inputs.
  mux3 #(WIDTH) extmux_u(sextb_result_node, sexth_result_node, zexth_result_node, ext_select, ext_result);
endmodule
