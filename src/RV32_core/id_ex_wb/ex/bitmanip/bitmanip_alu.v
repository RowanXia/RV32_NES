// Selects results from supported integer bit-manipulation operations.
// Combines bit-level arithmetic and logical subunits under decoded operation control.


`include "config.vh"

module bitmanip_alu   (
  input wire [31:0] primary_operand,  // First arithmetic or logical source operand.
  input wire [31:0] secondary_operand,  // Second arithmetic or logical source operand.
  input wire [3:0] b_select,  // Provides b select for this module.
  input wire [3:0] zbb_select,  // Provides zbb select for this module.
  input wire [2:0] funct3,  // Provides funct3 for this module.
  input wire lt,  // Provides lt for this module.
  input wire ltu,  // Provides ltu for this module.
  input wire [2:0] balu_control,  // Provides balu control for this module.
  input wire bitmanip_active,  // Provides bitmanip active for this module.
  input wire [31:0] pre_alu_result,  // ALU operation selection, operand, or result.
  input wire [31:0] full_result,  // Provides full result for this module.
  output wire [31:0] cond_mask_b,  // Provides cond mask b for this module.
  output wire [31:0] cond_shift_a,  // Provides cond shift a for this module.
  output reg [31:0] alu_result);  // ALU operation selection, operand, or result.

  wire [31:0] zbb_result;               
  wire [31:0] zbc_result;               
  wire [31:0] mask_b_node;                   
  wire [31:0] rev_a;                    
  wire mask_node;                    
  wire pre_shift_node;                
  wire [1:0] pre_shift_amt_node;             
  wire [31:0] cond_zext_a_node;               
  wire [31:0] gated_bitmanip_a_node;
  wire [31:0] gated_bitmanip_b_node;              

  
  assign gated_bitmanip_a_node = primary_operand & {32{bitmanip_active}};
  assign gated_bitmanip_b_node = secondary_operand & {32{bitmanip_active}};

  
  assign {mask_node, pre_shift_node} = balu_control[1:0];

  
  assign cond_zext_a_node = primary_operand;
  assign pre_shift_amt_node = funct3[2:1] & {2{pre_shift_node}};
  assign cond_shift_a = cond_zext_a_node << pre_shift_amt_node;

  
  // Convert a binary index into a one-hot selection.
  decoder #(5) maskgen_u(gated_bitmanip_b_node[5-1:0], mask_b_node);
  // Select the appropriate datapath value from the available inputs.
  mux2 #(32) maskmux_u(secondary_operand, mask_b_node, mask_node, cond_mask_b);

  
  bitreverse #(32) br_a_u(.primary_operand(gated_bitmanip_a_node), .rev_a(rev_a));

  
  zbb #(32) zbb_u(.primary_operand(gated_bitmanip_a_node), .rev_a(rev_a), .secondary_operand(gated_bitmanip_b_node), .lt(lt), .ltu(ltu), .b_unsigned(funct3[0]), .zbb_select(zbb_select[2:0]), .zbb_result(zbb_result));

  
  zbc zbc_u(.primary_operand(gated_bitmanip_a_node), .rev_a(rev_a), .secondary_operand(gated_bitmanip_b_node), .funct3(funct3[1:0]), .zbc_result(zbc_result));

  
  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    // Select the output behavior according to b_select.
    case (b_select)
      
      
      4'b0000: alu_result = pre_alu_result;
      4'b0001: alu_result = full_result;  
      4'b0010: alu_result = zbb_result;
      4'b0011: alu_result = zbc_result;
      default: alu_result = pre_alu_result;
    endcase
endmodule
