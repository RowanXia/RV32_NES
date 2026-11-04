// Combines direction, target, and return predictions for fetch control.
// Checks resolved control flow and reports prediction errors.


`include "config.vh"

module branch_predictor    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire FetchHold,  // Stops the fetch-side predictor state from advancing.
  input wire DecodeHold /* synthesis PAP_MARK_DEBUG="true" */,  // Holds predictor metadata associated with decode.
  input wire ExecuteHold /* synthesis PAP_MARK_DEBUG="true" */,  // Holds predictor metadata associated with execute.
  input wire MemoryHold /* synthesis PAP_MARK_DEBUG="true" */,  // Holds predictor metadata associated with memory.
  input wire WritebackHold,  // Holds predictor metadata associated with writeback.
  input wire DecodeKill /* synthesis PAP_MARK_DEBUG="true" */,  // Invalidates predictor metadata following decode cancellation.
  input wire ExecuteKill /* synthesis PAP_MARK_DEBUG="true" */,  // Invalidates execute-stage predictor metadata.
  input wire MemoryKill /* synthesis PAP_MARK_DEBUG="true" */,  // Invalidates memory-stage predictor metadata.
  input wire WritebackKill,  // Invalidates writeback-stage predictor metadata.
  
  
  input wire [31:0] instr_d,  // Decoded-stage instruction word.
  input wire [32-1:0] pc_next_f,  // Candidate address for the next instruction fetch.
  input wire [32-1:0] pc_plus2or4_f,  // Instruction address or PC selection for this stage.
  output wire [32-1:0] pc1_next_f,  // Pc1 next associated with the fetch-stage instruction.
  output wire [32-1:0] next_valid_pce,  // Provides next valid pce for this module.

  
  input wire [32-1:0] pcf,  // PC of the instruction being fetched.
  input wire [32-1:0] pcd,  // PC paired with the decode-stage instruction.
  input wire [32-1:0] pce,  // PC paired with the execute-stage instruction.
  input wire [32-1:0] pcm,  // PC paired with the memory-stage instruction.

  input wire [31:0] post_spill_instr_raw_f,  // Instruction word, decoded field, or validity qualifier.

  
  input wire instr_valid_d,  // Instruction word, decoded field, or validity qualifier.
  input wire instr_valid_e,  // Instruction word, decoded field, or validity qualifier.
  input wire branch_d,  // Identifies a conditional branch in decode.
  input wire branch_e,  // Identifies a conditional branch in the execute stage.
  input wire jump_d,  // Decode-stage jump classification.
  input wire jump_e,  // Execute-stage jump classification.
  input wire pc_src_e,  // Resolved execute-stage branch or jump redirection decision.
  input wire [32-1:0] resolved_control_flow_address_e,  // Address operand or target address selection.
  input wire [32-1:0] effective_address_m,  // Address operand or target address selection.
  input wire [32-1:0] link_address_e,  // Address operand or target address selection.
  output wire [3:0] instruction_class_m /* synthesis PAP_MARK_DEBUG="true" */,  // Instruction word, decoded field, or validity qualifier.

  
  output wire prediction_wrong_e,  // Branch prediction mismatch used for recovery.
  output wire prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  output wire direction_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  output wire target_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  output wire return_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  output wire instruction_class_wrong_m  // Instruction word, decoded field, or validity qualifier.
  );

  wire [1:0] direction_prediction_f /* synthesis PAP_MARK_DEBUG="true" */;

  wire direction_prediction_wrong_e;
  wire [32-1:0] btb_target_f;
  wire [32-1:0] return_stack_target_f;

  wire use_predicted_pcf_node;
  wire [32-1:0] predicted_target_pcf_node;
  wire [32-1:0] sequential_or_predicted_pcf_node;
  wire [32-1:0] resolved_next_pce_node;

  wire return_target_wrong_e_node;
  wire fallthrough_address_wrong_e_node;
  wire resolved_target_wrong_e_node;
  wire selected_next_address_wrong_e_node;

  wire btb_call_f;
  wire btb_return_f;
  wire btb_jump_f;
  wire btb_branch_f;
  wire predicted_branch_f;
  wire predicted_jump_f;
  wire predicted_return_f;
  wire predicted_call_f;
  wire predicted_branch_d_node;
  wire predicted_jump_d_node;
  wire predicted_return_d;
  wire predicted_call_d_node;
  wire return_d;
  wire call_d;
  wire return_e;
  wire call_e;
  wire branch_m;
  wire jump_m;
  wire return_m;
  wire call_m;
  wire branch_w;
  wire jump_w;
  wire return_w;
  wire call_w;
  wire return_class_wrong_d;
  wire btb_target_wrong_m;
  wire branch_taken_m_node;

  
  // Predict conditional branches using global history and a two-bit PHT.
  gshare direction_predictor_i_u(.clk(clk), .reset(reset), .FetchHold(FetchHold), .DecodeHold(DecodeHold), .ExecuteHold(ExecuteHold), .MemoryHold(MemoryHold), .WritebackHold(WritebackHold), .DecodeKill(DecodeKill), .ExecuteKill(ExecuteKill), .MemoryKill(MemoryKill), .WritebackKill(WritebackKill),
    .pc_next_f(pc_next_f), .pcf(pcf), .pcd(pcd), .pce(pce), .pcm(pcm), .direction_prediction_f(direction_prediction_f), .direction_prediction_wrong_e(direction_prediction_wrong_e),
    .predicted_branch_f(predicted_branch_f), .branch_d(branch_d), .branch_e(branch_e), .branch_m(branch_m), .branch_w(branch_w),
    .pc_src_e(pc_src_e));

  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(1) branch_taken_m_reg_u(clk, reset, MemoryKill, ~MemoryHold, pc_src_e, branch_taken_m_node);

  
  // Return predicted branch targets for matching fetch PCs.
  btb target_predictor_i_u(.clk(clk), .reset(reset), .FetchHold(FetchHold), .DecodeHold(DecodeHold), .ExecuteHold(ExecuteHold), .MemoryHold(MemoryHold), .WritebackHold(WritebackHold), .DecodeKill(DecodeKill), .ExecuteKill(ExecuteKill), .MemoryKill(MemoryKill), .WritebackKill(WritebackKill),
      .pc_next_f(pc_next_f), .pcf(pcf), .pcd(pcd), .pce(pce), .pcm(pcm),
      .btb_target_f(btb_target_f),
      .btb_instruction_class_f({btb_call_f, btb_return_f, btb_jump_f, btb_branch_f}),
      .btb_target_wrong_m(btb_target_wrong_m),
      .instruction_class_wrong_m(instruction_class_wrong_m),
      .resolved_control_flow_address_e(resolved_control_flow_address_e), .effective_address_m(effective_address_m),
      .instruction_class_d({call_d, return_d, jump_d, branch_d}),
      .instruction_class_e({call_e, return_e, jump_e, branch_e}),
      .instruction_class_m({call_m, return_m, jump_m, branch_m}),
      .instruction_class_w({call_w, return_w, jump_w, branch_w}));

  // Classify control-flow instructions for prediction and recovery.
  instruction_class instruction_class_i_u(.clk(clk), .reset(reset), .DecodeHold(DecodeHold), .ExecuteHold(ExecuteHold), .MemoryHold(MemoryHold), .WritebackHold(WritebackHold), .DecodeKill(DecodeKill), .ExecuteKill(ExecuteKill), .MemoryKill(MemoryKill),
    .post_spill_instr_raw_f(post_spill_instr_raw_f), .instr_d(instr_d), .branch_d(branch_d), .branch_e(branch_e), .jump_d(jump_d), .jump_e(jump_e), .branch_m(branch_m), .branch_w(branch_w), .jump_m(jump_m), .jump_w(jump_w),
    .call_d(call_d), .call_e(call_e), .call_m(call_m), .call_w(call_w), .return_d(return_d), .return_e(return_e), .return_m(return_m), .return_w(return_w), .btb_call_f(btb_call_f), .btb_return_f(btb_return_f), .btb_jump_f(btb_jump_f),
    .btb_branch_f(btb_branch_f), .predicted_call_f(predicted_call_f), .predicted_return_f(predicted_return_f), .predicted_jump_f(predicted_jump_f), .predicted_branch_f(predicted_branch_f), .instruction_class_wrong_m(instruction_class_wrong_m), .return_class_wrong_d(return_class_wrong_d), .predicted_return_d(predicted_return_d));

  
  // Predict return targets using a hardware call/return stack.
  return_stack  return_stack_i_u(.clk(clk), .reset(reset), .DecodeHold(DecodeHold), .ExecuteHold(ExecuteHold), .MemoryHold(MemoryHold), .DecodeKill(DecodeKill), .ExecuteKill(ExecuteKill), .MemoryKill(MemoryKill),
    .predicted_return_f(predicted_return_f), .return_d(return_d), .return_e(return_e), .call_e(call_e),
    .return_class_wrong_d(return_class_wrong_d), .predicted_return_d(predicted_return_d), .return_stack_target_f(return_stack_target_f), .link_address_e(link_address_e));

  
  // Select the address associated with the active request.
  assign fallthrough_address_wrong_e_node = link_address_e != pcd;
  assign resolved_target_wrong_e_node = resolved_control_flow_address_e != pcd;
  // Select the appropriate datapath value from the available inputs.
  mux2 #(1) next_address_wrong_mux_u(fallthrough_address_wrong_e_node, resolved_target_wrong_e_node, pc_src_e, selected_next_address_wrong_e_node);
  // Detect a mismatch between predicted and resolved control flow.
  assign prediction_wrong_e = selected_next_address_wrong_e_node & instr_valid_e & instr_valid_d;
  // Carry prediction/counter metadata to the next pipeline stage.
  ffenrc #(1) prediction_wrong_m_reg_u(clk, reset, MemoryKill, ~MemoryHold, prediction_wrong_e, prediction_wrong_m);

  
  assign use_predicted_pcf_node = (predicted_branch_f & direction_prediction_f[1]) | predicted_jump_f;
  // Select the appropriate datapath value from the available inputs.
  mux2 #(32) return_target_mux_u(btb_target_f, return_stack_target_f, predicted_return_f, predicted_target_pcf_node);
  
  // Select the PC source for the next fetch or recovery path.
  mux2 #(32) predicted_pc_mux_u(pc_plus2or4_f, predicted_target_pcf_node, use_predicted_pcf_node, sequential_or_predicted_pcf_node);
  
  // Select the PC source for the next fetch or recovery path.
  mux2 #(32) recovery_pc_mux_u(sequential_or_predicted_pcf_node, resolved_next_pce_node, prediction_wrong_e, pc1_next_f);
  
  // Select the PC source for the next fetch or recovery path.
  mux2 #(32) resolved_pc_mux_u(link_address_e, resolved_control_flow_address_e, pc_src_e, resolved_next_pce_node);

  
  // Select the PC source for the next fetch or recovery path.
  mux2 #(32) next_valid_pc_mux_u(pce, pcf, prediction_wrong_m, next_valid_pce);

  
  // Combine prediction metadata with resolved branch control.
  assign {target_prediction_wrong_m, return_prediction_wrong_m, direction_prediction_wrong_m} = 0;

  assign instruction_class_m = {call_m, return_m, jump_m, branch_m};

endmodule
