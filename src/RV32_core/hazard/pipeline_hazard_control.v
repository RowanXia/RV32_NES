// Computes pipeline Hold and Kill decisions from structural, execution, and control hazards.
// Propagates backpressure upstream and invalidates younger work after redirects or traps.


module pipeline_hazard_control (
  input wire prediction_wrong_e,  // Branch prediction mismatch used for recovery.
  input wire csr_write_fence_m,  // Serializes pipeline work around a CSR or fence operation.
  input wire ret_m,  // Requests machine-mode return from a trap.
  input wire trap_m,  // Requests entry into a machine-mode exception or interrupt handler.
  input wire structural_hold_d,  // Decode-side dependency or structural hazard request.
  input wire memory_hold_m,  // Indicates that the data-memory request is still pending.
  input wire fetch_hold_f,  // Indicates that instruction delivery is not ready.
  input wire external_hold,  // External backpressure request that suspends pipeline progression.
  input wire div_busy_e,  // Indicates an outstanding iterative division.
  input wire wait_m,  // Memory-side wait condition used by pipeline hazard control.
  
  output wire hold_f,  // Holds the fetch PC and prevents front-end advancement.
  output wire hold_d,  // Holds the decode-stage instruction and control state.
  output wire hold_e,  // Holds execute-stage operands and control until accepted.
  output wire hold_m,  // Holds the memory-stage transaction and state.
  output wire hold_w,  // Backpressure condition preventing writeback advancement.
  output wire kill_d,  // Invalidates decoded work on redirects and pipeline cancellation.
  output wire kill_e,  // Cancels younger execute-stage work or injects a bubble.
  output wire kill_m,  // Invalidates the instruction entering the memory stage.
  output wire kill_w  // Suppresses writeback for invalid or trapped instructions.
);

  wire hold_f_cause_node;
  wire hold_d_cause_node;
  wire hold_e_cause_node;
  wire hold_m_cause_node;
  wire hold_w_cause_node;
  wire latest_unstalled_d_node;
  wire latest_unstalled_e_node;
  wire latest_unstalled_m_node;
  wire kill_d_cause_node;
  wire kill_e_cause_node;
  wire kill_m_cause_node;
  wire kill_w_cause_node;

  
  // Invalidate younger instructions after a redirect or trap.
  // Decode is killed by redirects, traps, returns, and serializing operations.
  // A redirect or trap cancels younger instructions in decode.
  assign kill_d_cause_node = trap_m | ret_m | csr_write_fence_m | prediction_wrong_e;
  // Execution is cancelled for traps, returns, and eligible branch mispredictions.
  assign kill_e_cause_node = trap_m | ret_m | csr_write_fence_m | (prediction_wrong_e & ~div_busy_e);
  assign kill_m_cause_node = trap_m | ret_m | csr_write_fence_m;
  assign kill_w_cause_node = trap_m;

  
  // Apply stage backpressure when an instruction cannot advance.
  assign hold_f_cause_node = 1'b0;
  // Decode holds for a dependency unless a pending kill supersedes it.
  // Dependency backpressure is suppressed when a higher-priority decode kill applies.
  assign hold_d_cause_node = structural_hold_d & ~kill_d_cause_node;
  // Keep the execute stage occupied while division is unfinished.
  assign hold_e_cause_node = div_busy_e & ~kill_e_cause_node;
  assign hold_m_cause_node = 1'b0;
  
  
  // Fetch-side wait, memory-side wait, or an external request can block writeback progression.
  // Combine fetch, memory, and external backpressure into the writeback Hold cause.
  assign hold_w_cause_node = (fetch_hold_f & ~kill_d_cause_node) | ((memory_hold_m | wait_m) & ~kill_w_cause_node) | external_hold;

  
  // coverage off: hold_f_cause_node is always 0
  // Downstream holds propagate toward fetch to prevent instructions from overtaking.
  // Propagate downstream Hold conditions toward the instruction fetch stage.
  assign hold_f = hold_f_cause_node | hold_d;
  // coverage on
  // Qualify pipeline backpressure with the current request or stage state.
  assign hold_d = hold_d_cause_node | hold_e;
  assign hold_e = hold_e_cause_node | hold_m;
  // coverage off: hold_m_cause_node is always 0
  assign hold_m = hold_m_cause_node | hold_w;
  // coverage on
  assign hold_w = hold_w_cause_node;

  
  // Stage-boundary differences identify bubbles introduced by backpressure.
  // Detect boundaries where a downstream stage advances but its predecessor remains held.
  assign latest_unstalled_d_node = ~hold_d & hold_f; // coverage tag: hold_d always equals hold_f
  assign latest_unstalled_e_node = ~hold_e & hold_d;
  assign latest_unstalled_m_node = ~hold_m & hold_e;

  
  // Insert a bubble at stage boundaries or invalidate instructions on a redirect.
  assign kill_d = latest_unstalled_d_node | kill_d_cause_node; // coverage tag: latest_unstalled_d_node always 0
  assign kill_e = latest_unstalled_e_node | kill_e_cause_node;
  assign kill_m = latest_unstalled_m_node | kill_m_cause_node;
  // Kill at writeback suppresses invalid work when a machine trap is taken.
  assign kill_w = kill_w_cause_node;
endmodule
