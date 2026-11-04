// Controls uncached single transfers on the AHB bus.
// Sequences address and data phases around the HREADY handshake.


module ahb_direct_fsm #(
  parameter [0:0] READ_ONLY = 1'b0
)(
  input wire hclk,  // Clock forwarded to the AHB interface.
  input wire hrese_tn,  // Active-low AHB reset generated from the core reset.
  input wire hold,  // Prevents the corresponding pipeline stage from advancing.
  input wire kill,  // Cancels invalid or wrong-path pipeline work.
  input wire [1:0] bus_rw,  // Provides bus rw for this module.
  output wire capture_en,  // Provides capture en for this module.
  output wire bus_hold,  // Prevents the corresponding pipeline stage from advancing.
  output wire bus_committed,  // Provides bus committed for this module.
  input wire hready,  // AHB transfer-completion handshake from the selected slave.
  input wire hresp,  // AHB response status returned by the selected slave.
  output wire bus_error,  // Provides bus error for this module.
  output wire [1:0] htrans,  // AHB transfer type for the selected bus request.
  output wire hwrite  // Indicates an AHB write transfer.
);

  localparam [1:0] adr_phase_node = 2'd0;
  localparam [1:0] data_phase_node = 2'd1;
  localparam [1:0] mem3_node = 2'd2;
  localparam [1:0] ahb_idle_node = 2'b00;
  localparam [1:0] ahb_nonseq_node = 2'b10;

  reg [1:0] curr_state_node;
  reg [1:0] next_state_node;

  assign bus_error = hready & hresp & (curr_state_node == data_phase_node);

  // Update registered pipeline or controller state on the clock edge.
  // Register the controller state; reset and transition conditions determine each update.
  always @(posedge hclk)
    if (~hrese_tn | kill) curr_state_node <= adr_phase_node;
    else                  curr_state_node <= next_state_node;

  // Computes combinational outputs using decoded operation and state selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @* begin
    if (bus_error) next_state_node = mem3_node;
    else case(curr_state_node)
      adr_phase_node:  if(hready & |bus_rw)          next_state_node = data_phase_node;
                  else                         next_state_node = adr_phase_node;
      data_phase_node: if(hready)                   next_state_node = mem3_node;
                  else                         next_state_node = data_phase_node;
      mem3_node:       if(hold)                    next_state_node = mem3_node;
                  else                         next_state_node = adr_phase_node;
      default:                                 next_state_node = adr_phase_node;
    endcase
  end

  // Qualify pipeline backpressure with the current request or stage state.
  assign bus_hold = (curr_state_node == adr_phase_node & |bus_rw) | (curr_state_node == data_phase_node);
  assign bus_committed = (curr_state_node != adr_phase_node) & ~(READ_ONLY & curr_state_node == mem3_node);
  assign htrans = (curr_state_node == adr_phase_node & hready & |bus_rw & ~kill) ? ahb_nonseq_node : ahb_idle_node;
  assign hwrite = bus_rw[0];
  assign capture_en = curr_state_node == data_phase_node & ~bus_error;
endmodule
