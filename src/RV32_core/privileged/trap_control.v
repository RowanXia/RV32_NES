// Selects synchronous exceptions and machine interrupts for trap entry.
// Produces trap cause, return, and next-PC control signals.


`include "config.vh"

module trap_control    (
  input wire reset,  // Resets the local state and pipeline registers.
  input wire instr_misaligned_fault_m,  // Instruction word, decoded field, or validity qualifier.
  input wire instr_access_fault_m,  // Instruction word, decoded field, or validity qualifier.
  input wire illegal_instr_fault_m,  // Instruction word, decoded field, or validity qualifier.
  input wire breakpoint_fault_m,  // Breakpoint fault used by the memory-stage datapath or control.
  input wire load_misaligned_fault_m,  // Load misaligned fault used by the memory-stage datapath or control.
  input wire store_amo_misaligned_fault_m,  // Store amo misaligned fault used by the memory-stage datapath or control.
  input wire load_access_fault_m,  // Load access fault used by the memory-stage datapath or control.
  input wire store_amo_access_fault_m,  // Store amo access fault used by the memory-stage datapath or control.
  input wire ecall_fault_m,  // Ecall fault used by the memory-stage datapath or control.
  input wire waited_m,  // Waited used by the memory-stage datapath or control.
  input wire [11:0] mip_regw,  // Provides mip regw for this module.
  input wire [11:0] mie_regw,  // Provides mie regw for this module.
  input wire status_mie,  // Provides status mie for this module.
  input wire instr_valid_m,  // Instruction word, decoded field, or validity qualifier.
  input wire committed_m,  // Indicates that a memory-stage access has committed.
  input wire committed_f,  // Indicates that the fetch-side request was accepted or committed.
  output wire trap_m,  // Requests entry into a machine-mode exception or interrupt handler.
  output wire interrupt_m,  // Pending, enabled, or selected interrupt condition.
  output wire exception_m,  // Exception used by the memory-stage datapath or control.
  output wire int_pending_m,  // Interrupt pending used by the memory-stage datapath or control.
  output reg [4:0] cause_m  // Cause used by the memory-stage datapath or control.
);

  wire committed_node;                                       
  wire both_instr_access_fault_m_node;
  wire [11:0] pending_ints_m_node;
  wire [11:0] valid_ints_m_node;
  wire [11:0] enabled_ints_m_node;          

  
  assign pending_ints_m_node  = mip_regw & mie_regw;
  assign int_pending_m   = |pending_ints_m_node;
  assign committed_node     = committed_m | committed_f;
  assign enabled_ints_m_node  = status_mie ? pending_ints_m_node : 1'b0;
  
  
  assign valid_ints_m_node    = (committed_node | waited_m) ? 1'b0 : enabled_ints_m_node;
  assign interrupt_m    = (|valid_ints_m_node) & instr_valid_m;

  
  // Select or format the instruction for the next pipeline stage.
  assign both_instr_access_fault_m_node = instr_access_fault_m;
  // coverage off -item e 1 -fecexprrow 2
  
  assign exception_m = instr_misaligned_fault_m | both_instr_access_fault_m_node | illegal_instr_fault_m |
                      load_misaligned_fault_m | store_amo_misaligned_fault_m |
                      breakpoint_fault_m | ecall_fault_m |
                      load_access_fault_m | store_amo_access_fault_m;
  // coverage on
  // Select trap entry and return control conditions.
  assign trap_m = (exception_m & ~committed_f) | interrupt_m;

  
  // Compute combinational control and data selections.
  // Compute the combinational outputs from the current data and control inputs.
  always @*
    if      (reset)                                           cause_m = 5'd0; 
    else if (valid_ints_m_node[11])                                  cause_m = 5'd11; 
    else if (valid_ints_m_node[3])                                   cause_m = 5'd3;  
    else if (valid_ints_m_node[7])                                   cause_m = 5'd7;  
    else if (both_instr_access_fault_m_node)                           cause_m = 5'd1;
    else if (illegal_instr_fault_m)                              cause_m = 5'd2;
    // coverage off
    
    else if (instr_misaligned_fault_m)                           cause_m = 5'd0;
    // coverage on
    else if (breakpoint_fault_m)                                cause_m = 5'd3;
    else if (ecall_fault_m)                                     cause_m = 5'd11;
    else if (store_amo_misaligned_fault_m)                          cause_m = 5'd6;
    else if (load_misaligned_fault_m)                              cause_m = 5'd4;
    else if (store_amo_access_fault_m)                            cause_m = 5'd7;
    else if (load_access_fault_m)                                cause_m = 5'd5;
    else                                                      cause_m = 5'd0;
endmodule
