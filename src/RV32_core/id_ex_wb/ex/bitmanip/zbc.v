// Implements carry-less multiplication extension operations.
// Selects the requested portion of the carry-less product.


`include "config.vh"

module zbc   (
  input wire [31:0] primary_operand,  // First arithmetic or logical source operand.
  input wire [31:0] rev_a,  // Provides rev a for this module.
  input wire [31:0] secondary_operand,  // Second arithmetic or logical source operand.
  input wire [1:0] funct3,  // Provides funct3 for this module.
  output wire [31:0] zbc_result);  // Provides zbc result for this module.

  wire [31:0] clmul_result;
  wire [31:0] rev_clmul_result_node;
  wire [31:0] rev_b_node;
  wire [31:0] x;
  wire [31:0] operation_result;

  
  // Select this hardware path from the active configuration.
  if (`CFG_ZBC_SUPPORTED)
    // Select the appropriate datapath value from the available inputs.
    mux3 #(32) xmux_u({rev_a[30:0], {1'b0}}, rev_a, primary_operand, ~funct3[1:0], x);
  else
    // Select the appropriate datapath value from the available inputs.
    mux2 #(32) xmux_u(primary_operand, {rev_a[30:0], {1'b0}}, funct3[1], x);

  
  bitreverse #(32) br_b_u(secondary_operand, rev_b_node);
  // Select the appropriate datapath value from the available inputs.
  mux2 #(32) ymux_u(secondary_operand, rev_b_node, funct3[1], operation_result);

  
  clmul #(32) clm_u(.x(x), .operation_result(operation_result), .clmul_result(clmul_result));

  
  bitreverse #(32) br_clmul_result_u(clmul_result, rev_clmul_result_node);
  // Select the architectural writeback or execution result source.
  mux2 #(32) zbcresultmux_u(clmul_result, rev_clmul_result_node, funct3[1], zbc_result);
endmodule
