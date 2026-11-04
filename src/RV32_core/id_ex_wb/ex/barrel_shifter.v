// Executes logical and arithmetic shifts using operand and shift controls.
// Selects left or right shift behavior without a sequential shift loop.


`include "config.vh"

module barrel_shifter   (
  input wire [31:0] primary_operand,  // First arithmetic or logical source operand.
  input wire [4:0] amt,  // Provides amt for this module.
  input wire right,  // Provides right for this module.
  input wire rotate,  // Provides rotate for this module.
  input wire sub_arith,  // Provides sub arith for this module.
  output wire [31:0] operation_result);  // Provides operation result for this module.

  reg [62:0] z_node;
  wire [62:0] z_shift_node;                     
  wire [4:0] offset_1u_node;                        
  wire sign_node;                          

  
  assign offset_1u_node = right ? amt : ~amt;
  assign sign_node = primary_operand[31] & sub_arith;  
  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    // Select the output behavior according to {right, rotate}.
    case({right, rotate})
      2'b00: z_node = {primary_operand[31:0], 31'b0};
      2'b01: z_node = {primary_operand[31:0], primary_operand[31:1]};
      2'b10: z_node = {{31{sign_node}}, primary_operand[31:0]};
      2'b11: z_node = {primary_operand[30:0], primary_operand[31:0]};
    endcase
  
  assign z_shift_node = z_node >> offset_1u_node;
  assign operation_result = z_shift_node[31:0];
endmodule
