// Tracks machine interrupt enables and pending indications.
// Combines software-visible CSR bits with external interrupt inputs.


`include "config.vh"

module csr_interrupt    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire csrm_write_m,  // Control and status register access or state.
  input wire [31:0] csr_write_val_m,  // Control and status register access or state.
  input wire [11:0] csr_adr_m,  // Control and status register access or state.
  input wire m_ext_int,  // Machine external interrupt request.
  input wire m_timer_int,  // Machine timer interrupt request.
  input wire m_sw_int,  // Machine software interrupt request.
  output wire [11:0] mip_regw,  // Provides mip regw for this module.
  output reg [11:0] mie_regw,  // Provides mie regw for this module.
  output wire [11:0] mip_regw_writeable  // Provides mip regw writeable for this module.
);

  wire write_miem_node;

  localparam mie_node = 12'h304;

  
  assign write_miem_node = csrm_write_m & (csr_adr_m == mie_node);

  
  assign mip_regw_writeable = 12'b0;
  assign mip_regw = {m_ext_int, 3'b000, m_timer_int, 3'b000, m_sw_int, 3'b000};

  // Capture CSR or trap state on the clock edge.
  // Updates sequential state on the specified clock event.
  // Clock the mie_regw, mie_regw state under the specified reset and enable conditions.
  always @(posedge clk)
    if (reset)          mie_regw <= 12'b0;
    else if (write_miem_node) mie_regw <= csr_write_val_m[11:0] & 12'h888;
endmodule
