// Stores and looks up predicted branch targets by fetch PC.
// Updates target entries from resolved control transfers.


`include "config.vh"

module btb (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire FetchHold,  // Stops the fetch-side predictor state from advancing.
  input wire DecodeHold,  // Holds predictor metadata associated with decode.
  input wire ExecuteHold,  // Holds predictor metadata associated with execute.
  input wire MemoryHold,  // Holds predictor metadata associated with memory.
  input wire WritebackHold,  // Holds predictor metadata associated with writeback.
  input wire DecodeKill,  // Invalidates predictor metadata following decode cancellation.
  input wire ExecuteKill,  // Invalidates execute-stage predictor metadata.
  input wire MemoryKill,  // Invalidates memory-stage predictor metadata.
  input wire WritebackKill,  // Invalidates writeback-stage predictor metadata.
  input wire [32-1:0] pc_next_f,  // Candidate address for the next instruction fetch.
  input wire [32-1:0] pcf,  // PC of the instruction being fetched.
  input wire [32-1:0] pcd,  // PC paired with the decode-stage instruction.
  input wire [32-1:0] pce,  // PC paired with the execute-stage instruction.
  input wire [32-1:0] pcm,  // PC paired with the memory-stage instruction.
  
  input wire instruction_class_wrong_m,  // Instruction word, decoded field, or validity qualifier.
  input wire [32-1:0] resolved_control_flow_address_e,  // Address operand or target address selection.
  input wire [32-1:0] effective_address_m,  // Address operand or target address selection.
  input wire [3:0] instruction_class_d,  // Instruction word, decoded field, or validity qualifier.
  input wire [3:0] instruction_class_e,  // Instruction word, decoded field, or validity qualifier.
  input wire [3:0] instruction_class_m,  // Instruction word, decoded field, or validity qualifier.
  input wire [3:0] instruction_class_w,  // Instruction word, decoded field, or validity qualifier.
  output wire [32-1:0] btb_target_f,  // Btb target used by the fetch-stage datapath or control.
  output wire [3:0] btb_instruction_class_f,  // Instruction word, decoded field, or validity qualifier.
  output wire btb_target_wrong_m  // Btb target mismatch status observed in the memory stage.
);

  
  localparam integer index_bits_node = 10;

  wire [index_bits_node-1:0] next_fetch_index_node;
  wire [index_bits_node-1:0] fetch_index_node;
  wire [index_bits_node-1:0] decode_index_node;
  wire [index_bits_node-1:0] execute_index_node;
  wire [index_bits_node-1:0] memory_index_node;
  wire [index_bits_node-1:0] writeback_index_node;
  wire index_match_d_node;
  wire index_match_e_node;
  wire index_match_m_node;
  wire index_match_w_node;
  wire any_index_match_node;
  wire [32+3:0] forwarded_entry_f_node;
  wire [32+3:0] stored_entry_f_node;
  wire [32-1:0] resolved_target_w_node;
  wire [32-1:0] writeback_pc_node;
  wire [32-1:0] predicted_target_d_node;
  wire [32-1:0] predicted_target_e_node;
  wire target_mismatch_e_node;
  wire entry_update_m_node;


  // Form the lookup index for branch prediction storage.
  assign fetch_index_node = {pcf[index_bits_node+1] ^ pcf[1], pcf[index_bits_node:2]};
  assign decode_index_node = {pcd[index_bits_node+1] ^ pcd[1], pcd[index_bits_node:2]};
  assign execute_index_node = {pce[index_bits_node+1] ^ pce[1], pce[index_bits_node:2]};
  assign memory_index_node = {pcm[index_bits_node+1] ^ pcm[1], pcm[index_bits_node:2]};
  assign writeback_index_node = {writeback_pc_node[index_bits_node+1] ^ writeback_pc_node[1], writeback_pc_node[index_bits_node:2]};

  assign next_fetch_index_node = {pc_next_f[index_bits_node+1] ^ pc_next_f[1], pc_next_f[index_bits_node:2]};

  assign index_match_d_node = fetch_index_node == decode_index_node;
  assign index_match_e_node = fetch_index_node == execute_index_node;
  assign index_match_m_node = fetch_index_node == memory_index_node;
  assign index_match_w_node = fetch_index_node == writeback_index_node;
  assign any_index_match_node = index_match_d_node | index_match_e_node | index_match_m_node | index_match_w_node;

  assign forwarded_entry_f_node = index_match_d_node ? {instruction_class_d, predicted_target_d_node} :
                                 index_match_e_node ? {instruction_class_e, resolved_control_flow_address_e} :
                                 index_match_m_node ? {instruction_class_m, effective_address_m} :
                                 {instruction_class_w, resolved_target_w_node} ;

  assign {btb_instruction_class_f, btb_target_f} = any_index_match_node ? forwarded_entry_f_node : {stored_entry_f_node};

  
  if (1'b1) begin : pango_btb_memory
    // Map a 1024-word memory array onto an FPGA RAM primitive.
    pango_drm36k_1024x36_sdp memory_node(
      .clk(clk), .rd_ce(~FetchHold | reset), .rd_addr(next_fetch_index_node), .rd_data(stored_entry_f_node),
      .wr_ce(~WritebackHold & ~WritebackKill), .wr_addr(memory_index_node),
      .wr_data({instruction_class_m, effective_address_m}), .wr_en(entry_update_m_node));
  end

  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(32) execution_address_w_reg_u(clk, reset, ~WritebackHold, effective_address_m, resolved_target_w_node);
  // Register the associated stage PC using the configured Hold and reset behavior.
  ffenr #(32) pcw_reg_u(clk, reset, ~WritebackHold, pcm, writeback_pc_node);

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) btb_target_e_reg_u(clk, reset, ExecuteKill, ~ExecuteHold, predicted_target_d_node, predicted_target_e_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) btbd_u(clk, reset, DecodeKill, ~DecodeHold, btb_target_f, predicted_target_d_node);
  assign target_mismatch_e_node = (predicted_target_e_node != resolved_control_flow_address_e) & (instruction_class_e[0] | instruction_class_e[1] & ~instruction_class_e[2]);

  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(1) bpbta_wrong_m_reg_u(clk, reset, MemoryKill, ~MemoryHold, target_mismatch_e_node, btb_target_wrong_m);
  assign entry_update_m_node = btb_target_wrong_m | instruction_class_wrong_m;

endmodule
