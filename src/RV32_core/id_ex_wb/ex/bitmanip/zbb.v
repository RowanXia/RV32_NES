// Implements selected basic bit-manipulation operations.
// Combines dedicated byte, bit-count, and Boolean result paths.


module zbb #(parameter WIDTH=32) (
  input wire [WIDTH-1:0] primary_operand,  // First arithmetic or logical source operand.
  input wire [WIDTH-1:0] rev_a,  // Provides rev a for this module.
  input wire [WIDTH-1:0] secondary_operand,  // Second arithmetic or logical source operand.
  input wire lt,  // Provides lt for this module.
  input wire ltu,  // Provides ltu for this module.
  input wire b_unsigned,  // Provides b unsigned for this module.
  input wire [2:0] zbb_select,  // Provides zbb select for this module.
  output wire [WIDTH-1:0] zbb_result);  // Provides zbb result for this module.

  wire less_than_node;                        
  wire [WIDTH-1:0] cnt_result;           
  wire [WIDTH-1:0] min_max_result_node;        
  wire [WIDTH-1:0] byte_result;          
  wire [WIDTH-1:0] ext_result;           

  // Select the appropriate datapath value from the available inputs.
  mux2 #(1) ltmux_u(lt, ltu, b_unsigned , less_than_node);

  
  // Select the appropriate datapath value from the available inputs.
  mux2 #(WIDTH) minmaxmux_u(secondary_operand, primary_operand, zbb_select[2]^less_than_node, min_max_result_node);

  ext #(WIDTH) ext(.primary_operand(primary_operand[15:0]), .ext_select({~secondary_operand[2], {secondary_operand[2] & secondary_operand[0]}}), .ext_result(ext_result));
  byteop #(WIDTH) bu_u(.primary_operand(primary_operand), .byte_select(secondary_operand[0]), .byte_result(byte_result));
  cnt #(WIDTH) cnt(.primary_operand(primary_operand), .rev_a(rev_a), .secondary_operand(secondary_operand[1:0]), .cnt_result(cnt_result));

  
  // Select the architectural writeback or execution result source.
  mux4 #(WIDTH) zbbresultmux_u(cnt_result, ext_result, byte_result, min_max_result_node, zbb_select[1:0], zbb_result);
endmodule
