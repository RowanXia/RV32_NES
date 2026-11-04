// Decodes CSR accesses and connects machine-level register groups.
// Controls CSR read/write operations, exception state, and trap-vector outputs.


`include "config.vh"

module csr_unit    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  input wire kill_w,  // Suppresses writeback for invalid or trapped instructions.
  input wire hold_e,  // Holds execute-stage operands and control until accepted.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire hold_w,  // Backpressure condition preventing writeback advancement.
  input wire [31:0] instr_m,  // Instruction word carried into the memory stage.
  input wire [31:0] original_instr_m,  // Instruction word, decoded field, or validity qualifier.
  input wire [31:0] pcm,  // PC paired with the memory-stage instruction.
  input wire [31:0] pc_spill_m,  // Memory-stage PC adjusted for split instruction handling.
  input wire [31:0] csr_source_operand_m,  // Control and status register access or state.
  input wire [31:0] fault_address_m,  // Address operand or target address selection.
  input wire csr_read_m,  // Control and status register access or state.
  input wire csr_write_m,  // Control and status register access or state.
  input wire trap_m,  // Requests entry into a machine-mode exception or interrupt handler.
  input wire mret_m,  // Machine return instruction recognized in memory stage.
  input wire interrupt_m,  // Pending, enabled, or selected interrupt condition.
  input wire m_timer_int,  // Machine timer interrupt request.
  input wire m_ext_int,  // Machine external interrupt request.
  input wire m_sw_int,  // Machine software interrupt request.
  input wire [63:0] mtime_clint,  // 64-bit machine timer value from the local interrupt timer.
  input wire instr_valid_m,  // Instruction word, decoded field, or validity qualifier.
  input wire [4:0] cause_m,  // Cause used by the memory-stage datapath or control.
  
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
  input wire invalidate_i_cache_m,  // Cache-side data, address, or operation control.
  input wire div_busy_e,  // Indicates an outstanding iterative division.
  
  output wire [11:0] mip_regw,  // Provides mip regw for this module.
  output wire [11:0] mie_regw,  // Provides mie regw for this module.
  output wire status_mie,  // Provides status mie for this module.
  
  output wire [31:0] epcm,  // Exception return PC read from machine exception state.
  output wire [31:0] trap_vector_m,  // Exception/interrupt control or trap entry information.
  
  output wire [31:0] csr_read_val_w,  // Control and status register access or state.
  output wire illegal_csr_access_m  // Control and status register access or state.
);

  localparam mip_node = 12'h344;
  wire [31:0] csrm_read_val_m;
  wire [31:0] csrc_read_val_m;
  wire [31:0] csr_read_val_m_node;
  reg [31:0] csr_src_m_node;
  reg [31:0] csrrwm_node;
  reg [31:0] csrrsm_node;
  reg [31:0] csrrcm_node;
  reg [31:0] csr_write_val_m;
  wire [31:0] mstatus_regw;
  wire [31:0] mstatush_regw;
  wire [31:0] mtvec_regw;
  wire [31:0] mepc_regw;
  wire [31:0] mcountinhibit_regw;
  wire write_mstatusm;
  wire write_mstatushm;
  wire csrm_write_m;
  wire ungated_csrm_write_m;
  wire [31:0] unaligned_next_epcm_node;
  wire [31:0] next_epcm;
  wire [31:0] next_xtval_m;
  wire [5:0] next_cause_m;
  wire [11:0] csr_adr_m;
  wire illegal_csrc_access_m;
  wire illegal_csrm_access_m;
  wire illegal_csrm_write_readonly_m;
  reg [31:0] csr_read_val2_m_node;
  wire [11:0] mip_regw_writeable;
  reg [31:0] next_fault_xtval_m_node;
  wire m_trap_m;
  wire [31:0] t_vec_aligned_m_node;
  wire instr_valid_not_flushed_m;

  
  // A CSR instruction contributes state updates only when the stage can commit.
  assign instr_valid_not_flushed_m = instr_valid_m & ~hold_w & ~kill_w;

  
  // Combine privileged CSR results and readback selection.
  // Computes combinational outputs using decoded operation and state selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    if (interrupt_m)           next_fault_xtval_m_node = 1'b0;
    else case (cause_m)
      1:                      next_fault_xtval_m_node = pc_spill_m;  
      3:                      next_fault_xtval_m_node = pcm;       
      2:                      next_fault_xtval_m_node = {original_instr_m}; 
      0, 4, 6, 5, 7:          next_fault_xtval_m_node = fault_address_m; 
      default:                next_fault_xtval_m_node = 1'b0; 
    endcase

  
  assign t_vec_aligned_m_node = {mtvec_regw[31:2], 2'b00};

  
  // Select this hardware path from the active configuration.
  if (`CFG_VECTORED_INTERRUPTS_SUPPORTED) begin : vec
    wire vectored_m_node;
    wire [31:0] t_vec_plus_cause_m_node;
    assign vectored_m_node = interrupt_m & (mtvec_regw[1:0] == 2'b01);
    assign t_vec_plus_cause_m_node = {t_vec_aligned_m_node[31:6], cause_m[3:0], 2'b00}; 
    // Select the appropriate datapath value from the available inputs.
    mux2 #(32) trapvecmux_u(t_vec_aligned_m_node, t_vec_plus_cause_m_node, vectored_m_node, trap_vector_m);
  end else
    // Qualify exception or interrupt handling conditions.
    assign trap_vector_m = t_vec_aligned_m_node; 

  
  assign epcm = mepc_regw;

  
  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @* begin
    
    csr_src_m_node = instr_m[14] ? {{27{1'b0}}, instr_m[19:15]} : csr_source_operand_m;

    
    if (csr_adr_m == mip_node) csr_read_val2_m_node = {{20{1'b0}}, mip_regw_writeable};
    else                                 csr_read_val2_m_node = csr_read_val_m_node;

    
    csrrwm_node =   csr_src_m_node;
    csrrsm_node =   csr_read_val2_m_node | csr_src_m_node;
    csrrcm_node =   csr_read_val2_m_node & ~csr_src_m_node;
    // Select control behavior for the decoded state or operation.
    // Select the output behavior according to instr_m[13:12].
    case (instr_m[13:12])
      2'b01:   csr_write_val_m = csrrwm_node;
      2'b10:   csr_write_val_m = csrrsm_node;
      2'b11:   csr_write_val_m = csrrcm_node;
      default: csr_write_val_m = csr_read_val_m_node;
    endcase
  end

  
  // Select the address associated with the active request.
  assign csr_adr_m = instr_m[31:20];
  assign unaligned_next_epcm_node = trap_m ? pcm : csr_write_val_m;
  assign next_epcm = `CFG_ZCA_SUPPORTED ? {unaligned_next_epcm_node[31:1], 1'b0} : {unaligned_next_epcm_node[31:2], 2'b00}; 
  assign next_cause_m = trap_m ? {interrupt_m, cause_m}: {csr_write_val_m[31], csr_write_val_m[4:0]};
  assign next_xtval_m = trap_m ? next_fault_xtval_m_node : csr_write_val_m;
  assign ungated_csrm_write_m = csr_write_m;
  assign csrm_write_m = ungated_csrm_write_m & instr_valid_not_flushed_m;
  
  assign m_trap_m = trap_m & ~hold_w;

  
  // Implement machine status and interrupt-enable state transitions.
  csr_status  csr_status_i_u(.clk(clk), .reset(reset), .hold_w(hold_w),
    .write_mstatusm(write_mstatusm), .trap_m(trap_m), .mret_m(mret_m), .csr_write_val_m(csr_write_val_m),
    .mstatus_regw(mstatus_regw), .mstatush_regw(mstatush_regw), .status_mie(status_mie));

  // Manage machine interrupt enable and pending register fields.
  csr_interrupt  csr_interrupt_i_u(.clk(clk), .reset(reset), .csrm_write_m(csrm_write_m), .csr_write_val_m(csr_write_val_m), .csr_adr_m(csr_adr_m),
    .m_ext_int(m_ext_int), .m_timer_int(m_timer_int), .m_sw_int(m_sw_int), .mip_regw(mip_regw), .mie_regw(mie_regw), .mip_regw_writeable(mip_regw_writeable));

  // Implement machine-mode CSR state and reported processor identity.
  csr_machine  csr_machine_i_u(.clk(clk), .reset(reset),
    .ungated_csrm_write_m(ungated_csrm_write_m), .csrm_write_m(csrm_write_m), .m_trap_m(m_trap_m), .csr_adr_m(csr_adr_m),
    .next_epcm(next_epcm), .next_cause_m(next_cause_m), .next_xtval_m(next_xtval_m), .mstatus_regw(mstatus_regw), .mstatush_regw(mstatush_regw),
    .csr_write_val_m(csr_write_val_m), .csrm_read_val_m(csrm_read_val_m), .mtvec_regw(mtvec_regw),
    .mepc_regw(mepc_regw), .mcountinhibit_regw(mcountinhibit_regw),
    .mip_regw(mip_regw), .mie_regw(mie_regw), .write_mstatusm(write_mstatusm), .write_mstatushm(write_mstatushm),
    .illegal_csrm_access_m(illegal_csrm_access_m), .illegal_csrm_write_readonly_m(illegal_csrm_write_readonly_m));

  
  // Implement cycle/instret counters and counter CSR access.
  csr_counters  csr_counters_i_u(.clk(clk), .reset(reset), .hold_e(hold_e), .hold_m(hold_m), .hold_w(hold_w), .kill_m(kill_m),
    .instr_valid_not_flushed_m(instr_valid_not_flushed_m), .load_hold_d(load_hold_d), .store_hold_d(store_hold_d), .csr_write_m(csr_write_m), .csrm_write_m(csrm_write_m),
    .direction_prediction_wrong_m(direction_prediction_wrong_m), .target_prediction_wrong_m(target_prediction_wrong_m), .return_prediction_wrong_m(return_prediction_wrong_m), .instruction_class_wrong_m(instruction_class_wrong_m), .prediction_wrong_m(prediction_wrong_m),
    .instruction_class_m(instruction_class_m), .d_cache_miss(d_cache_miss), .d_cache_access(d_cache_access), .i_cache_miss(i_cache_miss), .i_cache_access(i_cache_access),
    .interrupt_m(interrupt_m), .trap_m(trap_m), .invalidate_i_cache_m(invalidate_i_cache_m), .i_cache_hold_f(i_cache_hold_f), .d_cache_hold_m(d_cache_hold_m), .div_busy_e(div_busy_e),
    .csr_adr_m(csr_adr_m), .csr_write_val_m(csr_write_val_m),
    .mcountinhibit_regw(mcountinhibit_regw),
    .mtime_clint(mtime_clint),  .csrc_read_val_m(csrc_read_val_m), .illegal_csrc_access_m(illegal_csrc_access_m));

  
  assign csr_read_val_m_node = csrm_read_val_m | csrc_read_val_m;
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) csr_val_w_reg_u(clk, reset, kill_w, ~hold_w, csr_read_val_m_node, csr_read_val_w);

  
  assign illegal_csr_access_m = (illegal_csrc_access_m & illegal_csrm_access_m & csr_read_m) |
                             illegal_csrm_write_readonly_m;
endmodule
