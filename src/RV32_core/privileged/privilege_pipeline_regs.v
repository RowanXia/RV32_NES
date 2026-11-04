// Transfers privilege and exception metadata between pipeline stages.
// Respects stage Hold and Kill controls.


module privilege_pipeline_regs (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_d,  // Holds the decode-stage instruction and control state.
  input wire hold_e,  // Holds execute-stage operands and control until accepted.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire kill_d,  // Invalidates decoded work on redirects and pipeline cancellation.
  input wire kill_e,  // Cancels younger execute-stage work or injects a bubble.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  input wire instr_access_fault_f,  // Instruction word, decoded field, or validity qualifier.
  input wire illegal_instr_d,  // Instruction word, decoded field, or validity qualifier.
  output wire instr_access_fault_m,  // Instruction word, decoded field, or validity qualifier.
  output wire illegal_instr_m  // Instruction word, decoded field, or validity qualifier.
);

  
  wire instr_access_fault_d_node;
  wire instr_access_fault_e_node;
  wire illegal_instr_e_node;

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(2) faultreg_m_u(clk, reset, kill_m, ~hold_m,
                  {illegal_instr_e_node, instr_access_fault_e_node},
                  {illegal_instr_m, instr_access_fault_m});
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(2) faultreg_e_u(clk, reset, kill_e, ~hold_e,
                  {illegal_instr_d, instr_access_fault_d_node},
                  {illegal_instr_e_node, instr_access_fault_e_node});
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(1) faultreg_d_u(clk, reset, kill_d, ~hold_d,
                  instr_access_fault_f, instr_access_fault_d_node);
endmodule
