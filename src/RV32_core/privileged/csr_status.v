// Maintains machine-mode status fields used by traps and returns.
// Updates interrupt-enable and privilege-related state.


`include "config.vh"

module csr_status    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_w,  // Backpressure condition preventing writeback advancement.
  input wire write_mstatusm,  // Provides write mstatusm for this module.
  input wire trap_m,  // Requests entry into a machine-mode exception or interrupt handler.
  input wire mret_m,  // Machine return instruction recognized in memory stage.
  input wire [31:0] csr_write_val_m,  // Control and status register access or state.
  output wire [31:0] mstatus_regw,  // Provides mstatus regw for this module.
  output wire [31:0] mstatush_regw,  // Provides mstatush regw for this module.
  output reg status_mie  // Provides status mie for this module.
);

  reg [1:0] status_mpp_node;
  wire [1:0] status_mpp_next_node;
  reg status_mpie_node;

  
  assign status_mpp_next_node = (csr_write_val_m[12:11] == (2'b11)) ? (2'b11) : status_mpp_node;

  
  assign mstatus_regw = {1'b0, 8'b0, 6'b0, 2'b0, 2'b0, status_mpp_node, 2'b0,
                         1'b0, status_mpie_node, 1'b0, 1'b0, 1'b0, status_mie, 1'b0, 1'b0, 1'b0};
  assign mstatush_regw = 1'b0;

  // Capture CSR or trap state on the clock edge.
  // Updates sequential state on the specified clock event.
  // Clock the status_mpp, status_mpie state under the specified reset and enable conditions.
  always @(posedge clk)
    if (reset) begin
      status_mpp_node  <= (2'b11);
      status_mpie_node <= 1'b0;
      status_mie  <= 1'b0;
    end else if (~hold_w) begin
      if (trap_m) begin
        status_mpie_node <= status_mie;
        status_mie  <= 1'b0;
        status_mpp_node  <= (2'b11);
      end else if (mret_m) begin
        status_mie  <= status_mpie_node;
        status_mpie_node <= 1'b1;
        status_mpp_node  <= (2'b11);
      end else if (write_mstatusm) begin
        status_mpp_node  <= status_mpp_next_node;
        status_mpie_node <= csr_write_val_m[7];
        status_mie  <= csr_write_val_m[3];
      end
    end
endmodule
