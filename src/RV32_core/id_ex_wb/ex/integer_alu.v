// Executes integer arithmetic, logic, shift, comparison, and bit-manipulation operations.
// Selects the result using execution-stage operation controls.


`include "config.vh"

module integer_alu   (
  input wire [31:0] primary_operand,  // First arithmetic or logical source operand.
  input wire [31:0] secondary_operand,  // Second arithmetic or logical source operand.
  input wire sub_arith,  // Provides sub arith for this module.
  input wire [2:0] alu_select,  // ALU operation selection, operand, or result.
  input wire [3:0] b_select,  // Provides b select for this module.
  input wire [3:0] zbb_select,  // Provides zbb select for this module.
  input wire [2:0] funct3,  // Provides funct3 for this module.
  input wire [2:0] balu_control,  // Provides balu control for this module.
  input wire bitmanip_active,  // Provides bitmanip active for this module.
  output wire [31:0] alu_result,  // ALU operation selection, operand, or result.
  output wire [31:0] sum);  // Provides sum for this module.

  
  wire [31:0] cond_mask_inv_b_node;
  wire [31:0] shift_result_node;
  reg [31:0] full_result;
  wire [31:0] pre_alu_result;               
  wire [31:0] cond_mask_b;                                                   
  wire [31:0] cond_shift_a;                                                  
  wire [31:0] bitwise_and_result_node;                                                   
  wire add_carry_node;
  wire sum_negative_node;                                                  
  wire signed_less_node;
  wire unsigned_less_node;                                                     
  wire operand_a_sign_node;
  wire operand_b_sign_node;                                                

  
  assign cond_mask_inv_b_node = sub_arith ? ~cond_mask_b : cond_mask_b;
  assign {add_carry_node, sum} = cond_shift_a + cond_mask_inv_b_node + {{31{1'b0}}, sub_arith};

  
  assign sum_negative_node  = sum[31];
  assign operand_a_sign_node = primary_operand[31];
  assign operand_b_sign_node = secondary_operand[31];
  assign signed_less_node = operand_a_sign_node & ~operand_b_sign_node | operand_a_sign_node & sum_negative_node | ~operand_b_sign_node & sum_negative_node;
  assign unsigned_less_node = ~add_carry_node;
  assign bitwise_and_result_node = primary_operand & cond_mask_inv_b_node;

  
  // Implement variable left/right shifts with signed/unsigned fill behavior.
  barrel_shifter barrel_shifter_i_u(.primary_operand(cond_shift_a), .amt(secondary_operand[4:0]), .right(funct3[2]), .sub_arith(sub_arith), .operation_result(shift_result_node), .rotate(balu_control[2]));

  
  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    // Select the output behavior according to alu_select.
    case (alu_select)
      3'b000: full_result = sum;                            
      3'b001: full_result = shift_result_node;                          
      3'b010: full_result = {{31{1'b0}}, signed_less_node};       
      3'b011: full_result = {{31{1'b0}}, unsigned_less_node};      
      3'b100: full_result = primary_operand ^ cond_mask_inv_b_node;               
      3'b101: full_result = (`CFG_ZBS_SUPPORTED) ? {{31{1'b0}},{|(bitwise_and_result_node)}} : shift_result_node; 
      3'b110: full_result = primary_operand | cond_mask_inv_b_node;               
      3'b111: full_result = bitwise_and_result_node;                      
    endcase

  // Produce the selected arithmetic or logic result.
  assign pre_alu_result = full_result;

  
  bitmanip_alu bitmanip_alu_i_u(
    .primary_operand(primary_operand), .secondary_operand(secondary_operand), .b_select(b_select), .zbb_select(zbb_select), .bitmanip_active(bitmanip_active),
    .funct3(funct3), .lt(signed_less_node), .ltu(unsigned_less_node), .balu_control(balu_control), .pre_alu_result(pre_alu_result), .full_result(full_result),
    .cond_mask_b(cond_mask_b), .cond_shift_a(cond_shift_a), .alu_result(alu_result));

endmodule
