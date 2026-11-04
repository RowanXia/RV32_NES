// Decodes privileged and CSR instruction operations.
// Identifies exceptions, returns, and system-control instructions.


`include "config.vh"

module privileged_decode    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire [31:7 ] instr_m,  // Instruction word carried into the memory stage.
  input wire privileged_m,  // Privileged used by the memory-stage datapath or control.
  input wire illegal_instr_m,  // Instruction word, decoded field, or validity qualifier.
  input wire illegal_csr_access_m,  // Control and status register access or state.
  input wire int_pending_m,  // Interrupt pending used by the memory-stage datapath or control.
  output wire illegal_instr_fault_m,  // Instruction word, decoded field, or validity qualifier.
  output wire ecall_fault_m,  // Ecall fault used by the memory-stage datapath or control.
  output wire breakpoint_fault_m,  // Breakpoint fault used by the memory-stage datapath or control.
  output wire mret_m,  // Machine return instruction recognized in memory stage.
  output wire ret_m,  // Requests machine-mode return from a trap.
  output wire wait_m,  // Memory-side wait condition used by pipeline hazard control.
  output wire waited_m  // Waited used by the memory-stage datapath or control.
);

  wire rs1zero_m_node;
  wire rdzero_m_node;                   
  wire illegal_privileged_instr_m_node;             
  wire wfi_m_node;                                
  wire waited_next_m_node;                         
  wire ebreak_m_node;
  wire ecall_m_node;                     

  
  assign rs1zero_m_node =    instr_m[19:15] == 5'b0;
  assign rdzero_m_node  =    instr_m[11:7]  == 5'b0;

  assign mret_m =      privileged_m & (instr_m[31:20] == 12'b001100000010) & rs1zero_m_node;
  assign ret_m =       mret_m;
  assign ecall_m_node =     privileged_m & (instr_m[31:20] == 12'b000000000000) & rs1zero_m_node;
  assign ebreak_m_node =    privileged_m & (instr_m[31:20] == 12'b000000000001) & rs1zero_m_node;
  assign wfi_m_node =       privileged_m & (instr_m[31:20] == 12'b000100000101) & rs1zero_m_node;

  
  assign wait_m = wfi_m_node & ~int_pending_m;

  
  assign waited_next_m_node = hold_m & (wait_m | waited_m);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffr #(1) waitedreg_u(clk, reset, waited_next_m_node, waited_m);

  
  // Select or format the instruction for the next pipeline stage.
  assign illegal_privileged_instr_m_node = privileged_m & ~(mret_m | ecall_m_node | ebreak_m_node | wfi_m_node);
  assign illegal_instr_fault_m = illegal_instr_m | illegal_privileged_instr_m_node | illegal_csr_access_m;

  
  assign breakpoint_fault_m = ebreak_m_node; 
  assign ecall_fault_m = ecall_m_node;
endmodule
