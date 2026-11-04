// Coordinates privileged instruction processing, CSR access, and trap logic.
// Connects exceptions and interrupts to architectural control-flow changes.


`include "config.vh"

module privilege_unit    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_d,  // Holds the decode-stage instruction and control state.
  input wire hold_e,  // Holds execute-stage operands and control until accepted.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire hold_w,  // Backpressure condition preventing writeback advancement.
  input wire kill_d,  // Invalidates decoded work on redirects and pipeline cancellation.
  input wire kill_e,  // Cancels younger execute-stage work or injects a bubble.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  input wire kill_w,  // Suppresses writeback for invalid or trapped instructions.
  
  input wire csr_read_m,  // Control and status register access or state.
  input wire csr_write_m,  // Control and status register access or state.
  input wire [31:0] csr_source_operand_m,  // Control and status register access or state.
  input wire [31:0] instr_m,  // Instruction word carried into the memory stage.
  input wire [31:0] original_instr_m,  // Instruction word, decoded field, or validity qualifier.
  input wire [31:0] fault_address_m,  // Address operand or target address selection.
  input wire [31:0] pcm,  // PC paired with the memory-stage instruction.
  input wire [31:0] pc_spill_m,  // Memory-stage PC adjusted for split instruction handling.
  
  input wire instr_valid_m,  // Instruction word, decoded field, or validity qualifier.
  input wire committed_m,  // Indicates that a memory-stage access has committed.
  input wire committed_f,  // Indicates that the fetch-side request was accepted or committed.
  input wire privileged_m,  // Privileged used by the memory-stage datapath or control.
  
  input wire load_hold_d,  // Prevents the corresponding pipeline stage from advancing.
  input wire store_hold_d,  // Prevents the corresponding pipeline stage from advancing.
  input wire i_cache_hold_f,  // Backpressure caused by an unresolved cache operation.
  input wire d_cache_hold_m,  // Backpressure caused by an unresolved cache operation.
  input wire direction_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  input wire target_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  input wire return_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  input wire instruction_class_wrong_m,  // Instruction word, decoded field, or validity qualifier.
  input wire prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  input wire [3:0] instruction_class_m,  // Instruction word, decoded field, or validity qualifier.
  input wire d_cache_miss,  // Cache miss indication for line refill processing.
  input wire d_cache_access,  // Cache-side data, address, or operation control.
  input wire i_cache_miss,  // Cache miss indication for line refill processing.
  input wire i_cache_access,  // Cache-side data, address, or operation control.
  input wire div_busy_e,  // Indicates an outstanding iterative division.
  
  input wire instr_access_fault_f,  // Instruction word, decoded field, or validity qualifier.
  input wire load_access_fault_m,  // Load access fault used by the memory-stage datapath or control.
  input wire store_amo_access_fault_m,  // Store amo access fault used by the memory-stage datapath or control.
  input wire instr_misaligned_fault_m,  // Instruction word, decoded field, or validity qualifier.
  input wire load_misaligned_fault_m,  // Load misaligned fault used by the memory-stage datapath or control.
  input wire store_amo_misaligned_fault_m,  // Store amo misaligned fault used by the memory-stage datapath or control.
  input wire illegal_instr_d,  // Instruction word, decoded field, or validity qualifier.
  input wire m_timer_int,  // Machine timer interrupt request.
  input wire m_ext_int,  // Machine external interrupt request.
  input wire m_sw_int,  // Machine software interrupt request.
  input wire [63:0] mtime_clint,  // 64-bit machine timer value from the local interrupt timer.
  
  output wire [31:0] csr_read_val_w,  // Control and status register access or state.
  
  output wire [31:0] epcm,  // Exception return PC read from machine exception state.
  output wire [31:0] trap_vector_m,  // Exception/interrupt control or trap entry information.
  
  output wire ret_m,  // Requests machine-mode return from a trap.
  output wire trap_m,  // Requests entry into a machine-mode exception or interrupt handler.
  input wire invalidate_i_cache_m,  // Cache-side data, address, or operation control.
  
  output wire wait_m  // Memory-side wait condition used by pipeline hazard control.
);

  wire [4:0] cause_m;                                         
  wire mret_m;                                          
  wire illegal_csr_access_m;                              
  wire illegal_instr_m;                                  
  wire instr_access_fault_m;                              
  wire illegal_instr_fault_m;                             
  wire status_mie;                                     
  wire [11:0] mip_regw;
  wire [11:0] mie_regw;                             
  wire interrupt_m;                                     
  wire exception_m;                                     
  wire breakpoint_fault_m;
  wire ecall_fault_m;                  

  wire int_pending_m;                                    
  wire waited_m;                                        

  
  // Identify privileged instructions and access faults.
  privileged_decode  privileged_decode_i_u(.clk(clk), .reset(reset), .hold_m(hold_m), .instr_m(instr_m[31:7]),
    .privileged_m(privileged_m), .illegal_instr_m(illegal_instr_m), .illegal_csr_access_m(illegal_csr_access_m),
    .int_pending_m(int_pending_m), .illegal_instr_fault_m(illegal_instr_fault_m),
    .ecall_fault_m(ecall_fault_m), .breakpoint_fault_m(breakpoint_fault_m), .mret_m(mret_m), .ret_m(ret_m), .wait_m(wait_m), .waited_m(waited_m));

  
  // Decode and execute CSR operations, exposing updated register values.
  csr_unit  csr_unit_i_u(.clk(clk), .reset(reset), .kill_m(kill_m), .kill_w(kill_w), .hold_e(hold_e), .hold_m(hold_m), .hold_w(hold_w),
    .instr_m(instr_m), .original_instr_m(original_instr_m), .pcm(pcm), .pc_spill_m(pc_spill_m), .csr_source_operand_m(csr_source_operand_m), .fault_address_m(fault_address_m),
    .csr_read_m(csr_read_m), .csr_write_m(csr_write_m), .trap_m(trap_m), .mret_m(mret_m), .interrupt_m(interrupt_m),
    .m_timer_int(m_timer_int), .m_ext_int(m_ext_int), .m_sw_int(m_sw_int),
    .mtime_clint(mtime_clint), .instr_valid_m(instr_valid_m), .load_hold_d(load_hold_d), .store_hold_d(store_hold_d),
    .direction_prediction_wrong_m(direction_prediction_wrong_m), .target_prediction_wrong_m(target_prediction_wrong_m), .return_prediction_wrong_m(return_prediction_wrong_m), .prediction_wrong_m(prediction_wrong_m),
    .invalidate_i_cache_m(invalidate_i_cache_m), .i_cache_hold_f(i_cache_hold_f), .d_cache_hold_m(d_cache_hold_m), .div_busy_e(div_busy_e),
    .instruction_class_wrong_m(instruction_class_wrong_m), .instruction_class_m(instruction_class_m), .d_cache_miss(d_cache_miss), .d_cache_access(d_cache_access), .i_cache_miss(i_cache_miss), .i_cache_access(i_cache_access),
    .cause_m(cause_m),
    .status_mie(status_mie),
    .mip_regw(mip_regw), .mie_regw(mie_regw),
    .epcm(epcm), .trap_vector_m(trap_vector_m),
    .csr_read_val_w(csr_read_val_w), .illegal_csr_access_m(illegal_csr_access_m));

  
  // Carry exception, privilege, and CSR control metadata between stages.
  privilege_pipeline_regs privilege_pipeline_regs_i_u(.clk(clk), .reset(reset), .hold_d(hold_d), .hold_e(hold_e), .hold_m(hold_m), .kill_d(kill_d), .kill_e(kill_e), .kill_m(kill_m),
    .instr_access_fault_f(instr_access_fault_f), .illegal_instr_d(illegal_instr_d),
    .instr_access_fault_m(instr_access_fault_m), .illegal_instr_m(illegal_instr_m));

  
  // Select trap/return redirects and update exception metadata.
  trap_control  trap_control_i_u(.reset(reset),
    .instr_misaligned_fault_m(instr_misaligned_fault_m), .instr_access_fault_m(instr_access_fault_m), .illegal_instr_fault_m(illegal_instr_fault_m),
    .breakpoint_fault_m(breakpoint_fault_m), .load_misaligned_fault_m(load_misaligned_fault_m), .store_amo_misaligned_fault_m(store_amo_misaligned_fault_m),
    .load_access_fault_m(load_access_fault_m), .store_amo_access_fault_m(store_amo_access_fault_m), .ecall_fault_m(ecall_fault_m),
    .mip_regw(mip_regw), .mie_regw(mie_regw), .status_mie(status_mie),
    .instr_valid_m(instr_valid_m), .committed_m(committed_m), .committed_f(committed_f),
    .trap_m(trap_m), .waited_m(waited_m), .interrupt_m(interrupt_m), .exception_m(exception_m), .int_pending_m(int_pending_m), .cause_m(cause_m));
endmodule
