// Indexes the branch direction table using global history XOR PC bits.
// Updates saturating counters and resolves in-flight table dependencies.


`include "config.vh"

module gshare (
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
  
  input wire [31:0] pc_next_f,  // Candidate address for the next instruction fetch.
  input wire [31:0] pcf,  // PC of the instruction being fetched.
  input wire [31:0] pcd,  // PC paired with the decode-stage instruction.
  input wire [31:0] pce,  // PC paired with the execute-stage instruction.
  input wire [31:0] pcm,  // PC paired with the memory-stage instruction.
  input wire predicted_branch_f,  // Fetch-stage prediction used for speculative history update.
  input wire branch_d,  // Identifies a conditional branch in decode.
  input wire branch_e,  // Identifies a conditional branch in the execute stage.
  input wire branch_m,  // Identifies a branch in the memory stage.
  input wire branch_w,  // Identifies a branch in the writeback stage.
  input wire pc_src_e,  // Resolved execute-stage branch or jump redirection decision.
  output wire [1:0] direction_prediction_f /* synthesis PAP_MARK_DEBUG="true" */,  // Predicted two-bit saturating counter for the fetch PC.
  output wire direction_prediction_wrong_e /* synthesis PAP_MARK_DEBUG="true" */  // Indicates that the resolved branch direction disagrees with prediction.
);

  
  localparam integer history_bits_node = 10;

  wire index_match_d_node;
  wire index_match_e_node /* synthesis PAP_MARK_DEBUG="true" */;
  wire index_match_m_node /* synthesis PAP_MARK_DEBUG="true" */;
  wire index_match_w_node /* synthesis PAP_MARK_DEBUG="true" */;
  wire any_index_match_node /* synthesis PAP_MARK_DEBUG="true" */;

  // Current two-bit direction prediction counter read from the table.
  wire [1:0] table_counter_f_node /* synthesis PAP_MARK_DEBUG="true" */;
  wire [1:0] direction_prediction_d_node;
  wire [1:0] direction_prediction_e_node /* synthesis PAP_MARK_DEBUG="true" */;
  wire [1:0] forwarded_counter_f_node;
  wire [1:0] updated_counter_e_node;
  wire [1:0] updated_counter_m_node;
  wire [1:0] updated_counter_w_node;

  wire [history_bits_node-1:0] next_lookup_index_f_node;
  // Combined fetch PC and history index used for direction-table lookup.
  wire [history_bits_node-1:0] lookup_index_f_node /* synthesis PAP_MARK_DEBUG="true" */;
  wire [history_bits_node-1:0] lookup_index_d_node;
  wire [history_bits_node-1:0] lookup_index_e_node;
  wire [history_bits_node-1:0] lookup_index_m_node /* synthesis PAP_MARK_DEBUG="true" */;
  wire [history_bits_node-1:0] lookup_index_w_node /* synthesis PAP_MARK_DEBUG="true" */;

  // History of recently resolved or predicted branch directions.
  wire [history_bits_node-1:0] global_history_f_node /* synthesis PAP_MARK_DEBUG="true" */;
  wire [history_bits_node-1:0] global_history_d_node;
  wire [history_bits_node-1:0] global_history_e_node;
  wire [history_bits_node-1:0] global_history_m_node;
  wire [history_bits_node-1:0] next_history_m_node;
  wire [history_bits_node-1:0] next_history_f_node;
  wire branch_taken_m_node;

  
  // Expose the prediction history, lookup and bypass state.
`ifdef CFG_ILA_PROBES
  // Observation-only probe bundle for internal debug and waveform capture.
  wire [27:0] ila_gshare_trace /* synthesis PAP_MARK_DEBUG="true" */;
  assign ila_gshare_trace[9:0]   = global_history_f_node;
  assign ila_gshare_trace[19:10] = lookup_index_f_node;
  assign ila_gshare_trace[21:20] = table_counter_f_node;
  assign ila_gshare_trace[23:22] = direction_prediction_f;
  assign ila_gshare_trace[24]    = direction_prediction_e_node[1];
  assign ila_gshare_trace[25]    = pc_src_e;
  assign ila_gshare_trace[26]    = direction_prediction_wrong_e;
  assign ila_gshare_trace[27]    = any_index_match_node;
`endif

  // Combine global branch history with the PC index.
  // Form the next PHT index by XORing speculative history with the next fetch PC.
  assign next_lookup_index_f_node = next_history_f_node ^ {pc_next_f[history_bits_node+1] ^ pc_next_f[1], pc_next_f[history_bits_node:2]};
  // Form the lookup index for branch prediction storage.
  // Global history is XORed with PC bits to access the direction table.
  // Compute stage-specific PHT indices from corresponding PCs and global history.
  assign lookup_index_f_node = global_history_f_node ^ {pcf[history_bits_node+1] ^ pcf[1], pcf[history_bits_node:2]};
  assign lookup_index_d_node = global_history_d_node ^ {pcd[history_bits_node+1] ^ pcd[1], pcd[history_bits_node:2]};
  assign lookup_index_e_node = global_history_e_node ^ {pce[history_bits_node+1] ^ pce[1], pce[history_bits_node:2]};
  assign lookup_index_m_node = global_history_m_node ^ {pcm[history_bits_node+1] ^ pcm[1], pcm[history_bits_node:2]};


  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(history_bits_node) lookup_index_w_reg_u(clk, reset, WritebackKill, ~WritebackHold, lookup_index_m_node, lookup_index_w_node);

  // Table-index matches identify unresolved branches whose updates may need bypassing.
  // Detect unresolved branches targeting the current predictor table entry.
  assign index_match_d_node = branch_d & ~ExecuteKill & (lookup_index_f_node == lookup_index_d_node);
  assign index_match_e_node = branch_e & ~MemoryKill & (lookup_index_f_node == lookup_index_e_node);
  assign index_match_m_node = branch_m & ~WritebackKill & (lookup_index_f_node == lookup_index_m_node);
  assign index_match_w_node = branch_w & ~WritebackKill & (lookup_index_f_node == lookup_index_w_node);
  // A matching in-flight branch can bypass a not-yet-written predictor entry.
  assign any_index_match_node = index_match_d_node | index_match_e_node | index_match_m_node | index_match_w_node;

  // Select the newest in-flight counter update before falling back to the PHT.
  assign forwarded_counter_f_node = index_match_d_node ? {2{direction_prediction_d_node[1]}} :
                                   index_match_e_node ? {updated_counter_e_node} :
                                   index_match_m_node ? {updated_counter_m_node} :
                   updated_counter_w_node ;

  // Prefer forwarded branch state when its table index matches the fetch lookup.
  assign direction_prediction_f = any_index_match_node ? forwarded_counter_f_node : table_counter_f_node;

  
  // Implement the branch direction table using distributed RAM.
  pango_lutram_1024x2_sdp pattern_history_table_i_u(
    .clk(clk), .rd_ce(~FetchHold), .rd_addr(next_lookup_index_f_node), .rd_data(table_counter_f_node),
    .wr_ce(~WritebackHold & ~WritebackKill), .wr_addr(lookup_index_m_node), .wr_data(updated_counter_m_node),
    .wr_en(branch_m));

  // Carry prediction/counter metadata to the next pipeline stage.
  ffenrc #(2) prediction_d_reg_u(clk, reset,  DecodeKill, ~DecodeHold, direction_prediction_f, direction_prediction_d_node);
  // Carry prediction/counter metadata to the next pipeline stage.
  ffenrc #(2) prediction_e_reg_u(clk, reset,  ExecuteKill, ~ExecuteHold, direction_prediction_d_node, direction_prediction_e_node);

  // Update a two-bit saturating branch direction counter.
  sat_counter_2bit direction_counter_update_i_u(.br_dir(pc_src_e), .old_state(direction_prediction_e_node), .new_state(updated_counter_e_node));
  // Carry prediction/counter metadata to the next pipeline stage.
  ffenrc #(2) updated_counter_m_reg_u(clk, reset,  MemoryKill, ~MemoryHold, updated_counter_e_node, updated_counter_m_node);
  // Carry prediction/counter metadata to the next pipeline stage.
  ffenrc #(2) updated_counter_w_reg_u(clk, reset,  WritebackKill, ~WritebackHold, updated_counter_m_node, updated_counter_w_node);

  // Detect a mismatch between predicted and resolved control flow.
  // Prediction correctness is evaluated when branch direction is resolved.
  // The resolved branch outcome is compared against the direction predicted for E.
  // Detect a resolved branch direction that disagrees with the saved prediction.
  assign direction_prediction_wrong_e = pc_src_e != direction_prediction_e_node[1] & branch_e;

  
  // Build speculative global history from the predicted branch direction.
  assign next_history_f_node = predicted_branch_f ? {direction_prediction_f[1], global_history_f_node[history_bits_node-1:1]} : global_history_f_node;
  // Recover or advance global history using in-flight branch outcomes.
  assign global_history_f_node = branch_d  ? {direction_prediction_d_node[1], global_history_d_node[history_bits_node-1:1]} : global_history_d_node;
  assign global_history_d_node = branch_e ? {pc_src_e, global_history_e_node[history_bits_node-1:1]} : global_history_e_node;
  assign global_history_e_node = branch_m ? {branch_taken_m_node, global_history_m_node[history_bits_node-1:1]} : global_history_m_node;

  assign next_history_m_node = {branch_taken_m_node, global_history_m_node[history_bits_node-1:1]};

  // Store branch history with the associated stage enable/reset controls.
  ffenr #(history_bits_node) global_history_reg_u(clk, reset, ~WritebackHold & ~WritebackKill & branch_m, next_history_m_node, global_history_m_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(1) branch_taken_m_reg_u(clk, reset, MemoryKill, ~MemoryHold, pc_src_e, branch_taken_m_node);

endmodule
