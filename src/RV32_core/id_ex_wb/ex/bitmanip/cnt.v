// Derives bit-count and leading/trailing-bit information.
// Selects the count format required by the decoded operation.


module cnt #(parameter WIDTH = 32) (
  input wire [WIDTH-1:0] primary_operand,  // First arithmetic or logical source operand.
  input wire [WIDTH-1:0] rev_a,  // Provides rev a for this module.
  input wire [1:0] secondary_operand,  // Second arithmetic or logical source operand.
  output wire [WIDTH-1:0] cnt_result  // Provides cnt result for this module.
);

  
  wire [WIDTH-1:0] cz_result_node;        
  wire [WIDTH-1:0] cpop_result_node;      
  wire [WIDTH-1:0] lzc_a_node;
  wire [WIDTH-1:0] popcnt_a_node;

  
  assign popcnt_a_node = primary_operand;
  popcnt #(WIDTH) popcntw_u(.num(popcnt_a_node), .pop_cnt(cpop_result_node[$clog2(WIDTH):0]));
  assign cpop_result_node[WIDTH-1:$clog2(WIDTH)+1] = 1'b0;

  
  // Count leading zero bits in an input word.
  lzc #(WIDTH) lzc(.num(lzc_a_node), .zero_cnt(cz_result_node[$clog2(WIDTH):0]));
  // Select the appropriate datapath value from the available inputs.
  mux2 #(WIDTH) lzcmux32_u(primary_operand, rev_a, secondary_operand[0], lzc_a_node);
  assign cz_result_node[WIDTH-1:$clog2(WIDTH)+1] = 1'b0;

  // Select the architectural writeback or execution result source.
  mux2 #(WIDTH) cntresultmux_u(cz_result_node, cpop_result_node, secondary_operand[1], cnt_result);
endmodule
