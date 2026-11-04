// Moves integer operands and results through decode, execute, and writeback paths.
// Selects forwarded operands and constructs effective addresses and branch targets.


`include "config.vh"

module pipeline_datapath    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  
  input wire [2:0] imm_src_d,  // Immediate field or immediate selection.
  input wire [31:0] instr_d,  // Decoded-stage instruction word.
  input wire [4:0] rs1_d,  // First source integer-register index or value.
  input wire [4:0] rs2_d,  // Second source integer-register index or value.
  
  input wire [31:0] pce,  // PC paired with the execute-stage instruction.
  input wire [31:0] link_address_e,  // Address operand or target address selection.
  input wire [2:0] funct3_e,  // Function-3 used by the execute-stage datapath or control.
  input wire hold_e,  // Holds execute-stage operands and control until accepted.
  input wire kill_e,  // Cancels younger execute-stage work or injects a bubble.
  input wire [1:0] forward_ae /* synthesis PAP_MARK_DEBUG="true" */,  // Forwarding selection for ALU source operand A.
  input wire [1:0] forward_be /* synthesis PAP_MARK_DEBUG="true" */,  // Forwarding selection for ALU source operand B.
  input wire sub_arith_e,  // Sub arith used by the execute-stage datapath or control.
  input wire alu_src_ae,  // First ALU operand or operand selector.
  input wire alu_src_be,  // Second ALU operand or operand selector.
  input wire alu_result_src_e,  // ALU operation selection, operand, or result.
  input wire [2:0] alu_select_e,  // ALU operation selection, operand, or result.
  input wire jump_e,  // Execute-stage jump classification.
  input wire branch_signed_e,  // Branch signed used by the execute-stage datapath or control.
  input wire [3:0] b_select_e,  // B select used by the execute-stage datapath or control.
  input wire [3:0] zbb_select_e,  // Zbb select used by the execute-stage datapath or control.
  input wire [2:0] balu_control_e,  // Bit-manipulation alu control used by the execute-stage datapath or control.
  input wire bitmanip_active_e,  // Bitmanip active used by the execute-stage datapath or control.
  output wire [1:0] flags_e,  // Flags used by the execute-stage datapath or control.
  output wire [31:0] effective_address_e,  // Address operand or target address selection.
  output wire [31:0] resolved_control_flow_address_e,  // Address operand or target address selection.
  output wire [31:0] forwarded_src_ae,  // Operand value after bypass/forwarding selection.
  output wire [31:0] forwarded_src_be,  // Operand value after bypass/forwarding selection.
  
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  output wire [31:0] csr_source_operand_m,  // Control and status register access or state.
  output wire [31:0] store_data_m,  // Store data used by the memory-stage datapath or control.
  
  input wire hold_w,  // Backpressure condition preventing writeback advancement.
  input wire kill_w,  // Suppresses writeback for invalid or trapped instructions.
  input wire reg_write_w /* synthesis PAP_MARK_DEBUG="true" */,  // Enables writeback to the integer register file.
  input wire [2:0] result_src_w,  // Result source used by the writeback-stage datapath or control.
  input wire [31:0] load_data_w,  // Load data used by the writeback-stage datapath or control.
  input wire [31:0] csr_read_val_w,  // Control and status register access or state.
  input wire [31:0] mul_div_result_w,  // Multiplication division result used by the writeback-stage datapath or control.
  input wire [4:0] rd_w /* synthesis PAP_MARK_DEBUG="true" */  // Destination register index carried into writeback.
   
);

  
  wire [31:0] register_operand1_d_node;
  wire [31:0] register_operand2_d_node;                       
  wire [31:0] extended_immediate_d;                        
  
  wire [31:0] register_operand1_e_node;
  wire [31:0] register_operand2_e_node;                       
  wire [31:0] extended_immediate_e_node;                        
  wire [31:0] alu_operand_ae_node;
  wire [31:0] alu_operand_be_node;                   
  wire [31:0] alu_result_e_node;
  wire [31:0] alternate_result_e_node;
  wire [31:0] integer_result_e_node; 
  wire [31:0] raw_execution_address_e_node;                     
  wire [31:0] raw_control_flow_address_e_node;              
  
  wire [31:0] integer_result_m_node;                     
  
  wire [31:0] writeback_result_w_node /* synthesis PAP_MARK_DEBUG="true" */;                        
  wire [31:0] integer_result_w_node;                     

  
  // Extract and sign-extend RISC-V instruction immediate formats.
  immediate_decode         immediate_decode_i_u(.instr_d(instr_d[31:7]), .imm_src_d(imm_src_d), .extended_immediate_d(extended_immediate_d));
  // Store integer architectural registers and provide the source operand read ports.
  register_file register_file_i_u(clk, reset, reg_write_w, rs1_d, rs2_d, rd_w, writeback_result_w_node, register_operand1_d_node, register_operand2_d_node);

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) operand1_e_reg_u(clk, reset, kill_e, ~hold_e, register_operand1_d_node, register_operand1_e_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) operand2_e_reg_u(clk, reset, kill_e, ~hold_e, register_operand2_d_node, register_operand2_e_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) extended_immediate_e_reg_u(clk, reset, kill_e, ~hold_e, extended_immediate_d, extended_immediate_e_node);

  // Select forwarded operand data for a dependent instruction.
  mux3  #(32)  forward_operand_b_mux_u(register_operand2_e_node, writeback_result_w_node, integer_result_m_node, forward_be, forwarded_src_be);
  // Select forwarded operand data for a dependent instruction.
  mux3  #(32)  forward_operand_a_mux_u(register_operand1_e_node, writeback_result_w_node, integer_result_m_node, forward_ae, forwarded_src_ae);
  // Compare branch source operands according to the branch condition.
  branch_compare #(32) branch_compare_i_u(forwarded_src_ae, forwarded_src_be, branch_signed_e, flags_e);
  // Select the appropriate datapath value from the available inputs.
  mux2  #(32)  alu_operand_a_mux_u(forwarded_src_ae, pce, alu_src_ae, alu_operand_ae_node);
  // Select the appropriate datapath value from the available inputs.
  mux2  #(32)  alu_operand_b_mux_u(forwarded_src_be, extended_immediate_e_node, alu_src_be, alu_operand_be_node);
  // Select arithmetic, logical, shift, and bit-manipulation results.
  integer_alu          integer_alu_i_u(alu_operand_ae_node, alu_operand_be_node, sub_arith_e, alu_select_e, b_select_e, zbb_select_e, funct3_e, balu_control_e, bitmanip_active_e, alu_result_e_node, raw_execution_address_e_node);
  // Select the architectural writeback or execution result source.
  mux2  #(32)  alternate_result_mux_u(extended_immediate_e_node, link_address_e, jump_e, alternate_result_e_node);
  // Select the architectural writeback or execution result source.
  mux2  #(32)  execute_result_mux_u(alu_result_e_node, alternate_result_e_node, alu_result_src_e, integer_result_e_node);

  
  // Select the address associated with the active request.
  assign effective_address_e = {raw_execution_address_e_node[31:1], raw_execution_address_e_node[0] & ~jump_e};
  
  
  assign raw_control_flow_address_e_node = alu_operand_ae_node + extended_immediate_e_node;
  assign resolved_control_flow_address_e = {raw_control_flow_address_e_node[31:1], raw_control_flow_address_e_node[0] & ~jump_e};

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) csr_source_m_reg_u(clk, reset, kill_m, ~hold_m, alu_operand_ae_node, csr_source_operand_m);
  // Register the computed result for the next pipeline stage.
  ffenrc #(32) integer_result_m_reg_u(clk, reset, kill_m, ~hold_m, integer_result_e_node, integer_result_m_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) store_data_m_reg_u(clk, reset, kill_m, ~hold_m, forwarded_src_be, store_data_m);

  
  // Register the computed result for the next pipeline stage.
  ffenrc #(32) integer_result_w_reg_u(clk, reset, kill_w, ~hold_w, integer_result_m_node, integer_result_w_node);
  // Select the architectural writeback or execution result source.
  mux4 #(32) writeback_result_mux_u(integer_result_w_node, load_data_w, csr_read_val_w, mul_div_result_w, result_src_w[1:0], writeback_result_w_node);
endmodule
