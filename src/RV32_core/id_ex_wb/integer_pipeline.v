// Combines integer decode, execution datapath, and writeback controls.
// Connects source operands, destination registers, forwarding, and results.


`include "config.vh"

module integer_pipeline    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  
  input wire [31:0] instr_d,  // Decoded-stage instruction word.
  input wire illegal_instr_d,  // Instruction word, decoded field, or validity qualifier.
  output wire illegal_base_instr_d,  // Instruction word, decoded field, or validity qualifier.
  
  input wire [31:0] pce,  // PC paired with the execute-stage instruction.
  input wire [31:0] link_address_e,  // Address operand or target address selection.
  output wire pc_src_e,  // Resolved execute-stage branch or jump redirection decision.
  output wire [31:0] effective_address_e,  // Address operand or target address selection.
  output wire [31:0] resolved_control_flow_address_e,  // Address operand or target address selection.
  output wire int_div_e,  // Selects integer division/remainder operations in execute.
  output wire [2:0] funct3_e,  // Function-3 used by the execute-stage datapath or control.
  output wire [31:0] forwarded_src_ae,  // Operand value after bypass/forwarding selection.
  output wire [31:0] forwarded_src_be,  // Operand value after bypass/forwarding selection.
  output wire [4:0] rd_e,  // Destination integer-register index.
  output wire mul_div_active_e,  // Multiplication division active used by the execute-stage datapath or control.
  
  output wire [1:0] memory_operation_e,  // Load/store memory interface or pipeline control.
  output wire [1:0] memory_operation_m,  // Load/store memory interface or pipeline control.
  output wire [31:0] store_data_m,  // Store data used by the memory-stage datapath or control.
  output wire [2:0] funct3_m,  // Function-3 used by the memory-stage datapath or control.
  output wire [31:0] csr_source_operand_m,  // Control and status register access or state.
  output wire [4:0] rd_m,  // Destination integer-register index.
  output wire invalidate_i_cache_m,  // Cache-side data, address, or operation control.
  output wire kill_d_cache_m,  // Cache-side data, address, or operation control.
  output wire instr_valid_d,  // Instruction word, decoded field, or validity qualifier.
  output wire instr_valid_e,  // Instruction word, decoded field, or validity qualifier.
  output wire instr_valid_m,  // Instruction word, decoded field, or validity qualifier.
  output wire branch_d,  // Identifies a conditional branch in decode.
  output wire branch_e,  // Identifies a conditional branch in the execute stage.
  output wire jump_d,  // Decode-stage jump classification.
  output wire jump_e,  // Execute-stage jump classification.
  
  input wire [31:0] csr_read_val_w,  // Control and status register access or state.
  input wire [31:0] mul_div_result_w,  // Multiplication division result used by the writeback-stage datapath or control.
  output wire [4:0] rd_w /* synthesis PAP_MARK_DEBUG="true" */,  // Destination register index carried into writeback.
  input wire [31:0] load_data_w,  // Load data used by the writeback-stage datapath or control.
  
  input wire hold_d,  // Holds the decode-stage instruction and control state.
  input wire hold_e,  // Holds execute-stage operands and control until accepted.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire hold_w,  // Backpressure condition preventing writeback advancement.
  input wire kill_d,  // Invalidates decoded work on redirects and pipeline cancellation.
  input wire kill_e,  // Cancels younger execute-stage work or injects a bubble.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  input wire kill_w,  // Suppresses writeback for invalid or trapped instructions.
  output wire structural_hold_d,  // Decode-side dependency or structural hazard request.
  output wire load_hold_d,  // Prevents the corresponding pipeline stage from advancing.
  output wire store_hold_d,  // Prevents the corresponding pipeline stage from advancing.
  output wire csr_read_m,  // Control and status register access or state.
  output wire csr_write_m,  // Control and status register access or state.
  output wire privileged_m,  // Privileged used by the memory-stage datapath or control.
  output wire csr_write_fence_m  // Serializes pipeline work around a CSR or fence operation.
);

  wire [2:0] imm_src_d;                                       
  wire [1:0] flags_e;                                        
  wire alu_src_ae;
  wire alu_src_be;                            
  wire [2:0] result_src_w;                                    
  wire alu_result_src_e;                                 
  wire [2:0] alu_select_e;                                    
  wire int_div_w;                                       
  wire [3:0] b_select_e;                                      
  wire [3:0] zbb_select_e;                                    
  wire [2:0] balu_control_e;                                  
  wire sub_arith_e;                                     

  
  wire [4:0] rs1_d;
  wire [4:0] rs2_d;
  wire [4:0] rs2_e;                                          
  // Source dependency or forwarding selection between in-flight instructions.
  wire [1:0] forward_ae /* synthesis PAP_MARK_DEBUG="true" */;
  // Source dependency or forwarding selection between in-flight instructions.
  wire [1:0] forward_be /* synthesis PAP_MARK_DEBUG="true" */;                          
  // Enables architectural register writeback in the WB stage.
  wire reg_write_w /* synthesis PAP_MARK_DEBUG="true" */;                                     
  wire branch_signed_e;                                 
  wire bitmanip_active_e;                                    

`ifdef CFG_ILA_PROBES_EXTRA
  // Observation-only probe bundle for internal debug and waveform capture.
  wire [3:0] ila_forward_select /* synthesis PAP_MARK_DEBUG="true" */;
  assign ila_forward_select = {forward_be, forward_ae};
`endif

  // Decode instruction classes and generate ALU, memory, branch, and writeback controls.
  pipeline_control  pipeline_control_i_u(
    .clk(clk), .reset(reset), .hold_d(hold_d), .kill_d(kill_d), .instr_d(instr_d), .imm_src_d(imm_src_d),
    .illegal_instr_d(illegal_instr_d), .illegal_base_instr_d(illegal_base_instr_d),
    .structural_hold_d(structural_hold_d), .load_hold_d(load_hold_d), .store_hold_d(store_hold_d), .rs1_d(rs1_d), .rs2_d(rs2_d),  .rs2_e(rs2_e),
    .hold_e(hold_e), .kill_e(kill_e), .flags_e(flags_e),
    .pc_src_e(pc_src_e), .alu_src_ae(alu_src_ae), .alu_src_be(alu_src_be), .alu_result_src_e(alu_result_src_e), .alu_select_e(alu_select_e),
    .funct3_e(funct3_e), .int_div_e(int_div_e), .sub_arith_e(sub_arith_e), .branch_d(branch_d), .branch_e(branch_e), .jump_d(jump_d), .jump_e(jump_e),
    .branch_signed_e(branch_signed_e), .b_select_e(b_select_e), .zbb_select_e(zbb_select_e), .balu_control_e(balu_control_e), .bitmanip_active_e(bitmanip_active_e), .mul_div_active_e(mul_div_active_e),
    .forward_ae(forward_ae), .forward_be(forward_be),
    .hold_m(hold_m), .kill_m(kill_m), .memory_operation_e(memory_operation_e), .memory_operation_m(memory_operation_m), .csr_read_m(csr_read_m), .csr_write_m(csr_write_m), .privileged_m(privileged_m), .funct3_m(funct3_m),
    .kill_d_cache_m(kill_d_cache_m), .instr_valid_m(instr_valid_m), .instr_valid_e(instr_valid_e), .instr_valid_d(instr_valid_d),
    .hold_w(hold_w), .kill_w(kill_w), .reg_write_w(reg_write_w), .int_div_w(int_div_w), .result_src_w(result_src_w), .csr_write_fence_m(csr_write_fence_m), .invalidate_i_cache_m(invalidate_i_cache_m),
    .rd_w(rd_w), .rd_e(rd_e), .rd_m(rd_m));

  // Compute integer results, branch conditions, addresses, and forwarded operands.
  pipeline_datapath  pipeline_datapath_i_u(
    .clk(clk), .reset(reset), .imm_src_d(imm_src_d), .instr_d(instr_d), .rs1_d(rs1_d), .rs2_d(rs2_d), .hold_e(hold_e), .kill_e(kill_e), .forward_ae(forward_ae), .forward_be(forward_be), .sub_arith_e(sub_arith_e),
    .funct3_e(funct3_e), .alu_src_ae(alu_src_ae), .alu_src_be(alu_src_be), .alu_result_src_e(alu_result_src_e), .alu_select_e(alu_select_e), .jump_e(jump_e), .branch_signed_e(branch_signed_e),
    .pce(pce), .link_address_e(link_address_e), .flags_e(flags_e), .effective_address_e(effective_address_e), .resolved_control_flow_address_e(resolved_control_flow_address_e), .forwarded_src_ae(forwarded_src_ae), .forwarded_src_be(forwarded_src_be), .b_select_e(b_select_e), .zbb_select_e(zbb_select_e), .balu_control_e(balu_control_e), .bitmanip_active_e(bitmanip_active_e),
    .hold_m(hold_m), .kill_m(kill_m), .csr_source_operand_m(csr_source_operand_m), .store_data_m(store_data_m),
    .hold_w(hold_w), .kill_w(kill_w), .reg_write_w(reg_write_w), .result_src_w(result_src_w), .load_data_w(load_data_w),
    .csr_read_val_w(csr_read_val_w), .mul_div_result_w(mul_div_result_w), .rd_w(rd_w));
endmodule
