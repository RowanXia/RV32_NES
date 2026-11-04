// Implements machine-mode configuration and identification CSRs.
// Qualifies register writes and returns the selected CSR read value.


`include "config.vh"

module csr_machine     (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire ungated_csrm_write_m,  // Control and status register access or state.
  input wire csrm_write_m,  // Control and status register access or state.
  input wire m_trap_m,  // Exception/interrupt control or trap entry information.
  input wire [11:0] csr_adr_m,  // Control and status register access or state.
  input wire [31:0] next_epcm,  // Provides next epcm for this module.
  input wire [31:0] next_xtval_m,  // Next xtval used by the memory-stage datapath or control.
  input wire [31:0] mstatus_regw,  // Provides mstatus regw for this module.
  input wire [31:0] mstatush_regw,  // Provides mstatush regw for this module.
  input wire [5:0] next_cause_m,  // Next cause used by the memory-stage datapath or control.
  input wire [31:0] csr_write_val_m,  // Control and status register access or state.
  input wire [11:0] mip_regw,  // Provides mip regw for this module.
  input wire [11:0] mie_regw,  // Provides mie regw for this module.
  output reg [31:0] csrm_read_val_m,  // Control and status register access or state.
  output wire [31:0] mtvec_regw,  // Provides mtvec regw for this module.
  output wire [31:0] mepc_regw,  // Provides mepc regw for this module.
  output wire [31:0] mcountinhibit_regw,  // Provides mcountinhibit regw for this module.
  output wire write_mstatusm,  // Provides write mstatusm for this module.
  output wire write_mstatushm,  // Provides write mstatushm for this module.
  output reg illegal_csrm_access_m,  // Control and status register access or state.
  output wire illegal_csrm_write_readonly_m  // Control and status register access or state.
);

  wire [31:0] misa_regw_node;
  wire [31:0] mhartid_regw_node;
  wire [31:0] mscratch_regw_node;
  wire [31:0] mtval_regw_node;
  wire [31:0] mcause_regw_node;
  wire [31:0] tvec_write_val_m_node;
  wire write_mtvecm_node;
  wire write_mscratchm_node;
  wire write_mepcm_node;
  wire write_mcausem_node;
  wire write_mtvalm_node;
  wire write_mcountinhibitm_node;

  
  // Machine identification and configuration CSR addresses.
  localparam mvendorid_node     = 12'hF11;
  localparam marchid_node       = 12'hF12; 
  localparam mimpid_node        = 12'hF13;
  localparam mhartid_node       = 12'hF14;
  localparam mconfigptr_node    = 12'hF15;
  localparam mstatus_node       = 12'h300;
  localparam misa_adr_node      = 12'h301;
  localparam mie_node           = 12'h304;
  localparam mtvec_node         = 12'h305;
  localparam mstatush_node      = 12'h310;
  localparam mcountinhibit_node = 12'h320;
  localparam mscratch_node      = 12'h340;
  localparam mepc_node          = 12'h341;
  localparam mcause_node        = 12'h342;
  localparam mtval_node         = 12'h343;
  localparam mip_node           = 12'h344;
  /* verilator lint_off UNUSEDPARAM */
  localparam tselect_node       = 12'h7A0;
  localparam tdata1_node        = 12'h7A1;
  localparam tdata2_node        = 12'h7A2;
  localparam tdata3_node        = 12'h7A3;
  localparam dcsr_node          = 12'h7B0;
  localparam dpc_node           = 12'h7B1;
  localparam dscratch0_node     = 12'h7B2;
  localparam dscratch1_node     = 12'h7B3;
  /* verilator lint_on UNUSEDPARAM */
  
  
  localparam counterinhibit_mask_node = ((1 << `CFG_COUNTERS) - 1) & 32'hFFFFFFFD;

  localparam [31:0] misa_value_node = `CFG_MISA;
  localparam [25:0] misa_26_node = misa_value_node[25:0];

  
  assign misa_regw_node = {2'b01, 4'b0000, misa_26_node[25:0]};

  
  assign mhartid_regw_node = 1'b0;

  
  // Decode writes to machine-mode control registers.
  assign write_mstatusm       = csrm_write_m & (csr_adr_m == mstatus_node);
  assign write_mstatushm      = csrm_write_m & (csr_adr_m == mstatush_node);
  assign write_mtvecm_node         = csrm_write_m & (csr_adr_m == mtvec_node);
  assign write_mscratchm_node      = csrm_write_m & (csr_adr_m == mscratch_node);
  assign write_mepcm_node          = m_trap_m | (csrm_write_m & (csr_adr_m == mepc_node));
  assign write_mcausem_node        = m_trap_m | (csrm_write_m & (csr_adr_m == mcause_node));
  assign write_mtvalm_node         = m_trap_m | (csrm_write_m & (csr_adr_m == mtval_node));
  assign write_mcountinhibitm_node = csrm_write_m & (csr_adr_m == mcountinhibit_node);

  assign illegal_csrm_write_readonly_m = ungated_csrm_write_m & (csr_adr_m == mvendorid_node | csr_adr_m == marchid_node | csr_adr_m == mimpid_node | csr_adr_m == mhartid_node | csr_adr_m == mconfigptr_node);

  
  assign tvec_write_val_m_node = (csr_write_val_m[0] & `CFG_VECTORED_INTERRUPTS_SUPPORTED) ? {csr_write_val_m[31:6], 6'b000001} : {csr_write_val_m[31:2], 2'b00};
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(32) mtve_creg_u(clk, reset, write_mtvecm_node, tvec_write_val_m_node, mtvec_regw);

  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(32)     mcountinhibi_treg_u(clk, reset, write_mcountinhibitm_node, csr_write_val_m[31:0] & counterinhibit_mask_node, mcountinhibit_regw);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(32) mtva_lreg_u(clk, reset, write_mtvalm_node, next_xtval_m, mtval_regw_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(32) mcaus_ereg_u(clk, reset, write_mcausem_node, {next_cause_m[5], {26{1'b0}}, next_cause_m[4:0]}, mcause_regw_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(32) mep_creg_u(clk, reset, write_mepcm_node, next_epcm, mepc_regw);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(32) mscratc_hreg_u(clk, reset, write_mscratchm_node, csr_write_val_m, mscratch_regw_node);
  
  // verilator lint_off WIDTH
  // Select CSR read data and report illegal accesses.
  // Computes combinational outputs using decoded operation and state selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @* begin
    csrm_read_val_m = 1'b0;
    illegal_csrm_access_m = 1'b0;
    // Select control behavior for the decoded state or operation.
    // Select the output behavior according to csr_adr_m.
    case (csr_adr_m)
      misa_adr_node:      csrm_read_val_m = misa_regw_node;
      mvendorid_node:     csrm_read_val_m = {32'h0000_0000}; 
      marchid_node:       csrm_read_val_m = {32'h0000_0000}; 
      mimpid_node:        csrm_read_val_m = {32'h0000_0000}; 
      mhartid_node:       csrm_read_val_m = mhartid_regw_node; 
      mconfigptr_node:    csrm_read_val_m = 1'b0; 
      mstatus_node:       csrm_read_val_m = mstatus_regw;
      mstatush_node:      csrm_read_val_m = mstatush_regw;
      mtvec_node:         csrm_read_val_m = mtvec_regw;
      mip_node:           csrm_read_val_m = {{20{1'b0}}, mip_regw};
      mie_node:           csrm_read_val_m = {{20{1'b0}}, mie_regw};
      mscratch_node:      csrm_read_val_m = mscratch_regw_node;
      mepc_node:          csrm_read_val_m = mepc_regw;
      mcause_node:        csrm_read_val_m = mcause_regw_node;
      mtval_node:         csrm_read_val_m = mtval_regw_node;
      mcountinhibit_node: csrm_read_val_m = {mcountinhibit_regw};
      default:       illegal_csrm_access_m = 1'b1;
    endcase
  end
  // verilator lint_on WIDTH
endmodule
