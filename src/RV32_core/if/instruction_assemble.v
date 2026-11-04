// Aligns instruction bytes and assembles a complete instruction from fetch data.
// Handles instruction boundaries and compressed-instruction alignment.


`include "config.vh"

module instruction_assemble    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_f,  // Holds the fetch PC and prevents front-end advancement.
  input wire kill_d,  // Invalidates decoded work on redirects and pipeline cancellation.
  input wire [31:0] pcf,  // PC of the instruction being fetched.
  input wire [31:2] pc_plus4_f,  // Instruction address or PC selection for this stage.
  input wire [31:0] pc_next_f,  // Candidate address for the next instruction fetch.
  input wire [31:0] instr_raw_f,  // Instruction word, decoded field, or validity qualifier.
  input wire fetch_cache_bus_hold_f,  // External memory transaction associated with cache control.
  input wire cacheable_f,  // Cache-side data, address, or operation control.
  input wire cached_spill_ready_f,  // Cache-side data, address, or operation control.
  input wire instr_access_fault_f,  // Instruction word, decoded field, or validity qualifier.
  output wire [31:0] pc_spill_next_f,  // Instruction address or PC selection for this stage.
  output wire [31:0] pc_spill_f,  // Fetch PC after instruction-alignment selection.
  output wire sel_spill_next_f,  // Selection spill next used by the fetch-stage datapath or control.
  output wire sel_spill_f,  // Selection spill used by the fetch-stage datapath or control.
  output wire [31:0] post_spill_instr_raw_f,  // Instruction word, decoded field, or validity qualifier.
  output reg compressed_f);  // Compressed used by the fetch-stage datapath or control.

  
  localparam [1:0] state_ready_node = 2'd0;
  localparam [1:0] state_spill_node = 2'd1;

  reg [1:0] curr_state_node;
  reg [1:0] next_state_node;
  wire [31:0] pc_plus2_next_f_node;
  wire [31:0] pc_plus2_f_node;
  wire take_spill_f_node;
  wire spill_f_node;
  wire spill_save_f_node;
  wire [15:0] instr_first_half_f_node;
  wire early_compressed_f_node;

  
  // Select the PC source for the next fetch or recovery path.
  mux2 #(32) pcplus2mux_u(.d0({pcf[31:2], 2'b10}), .d1({pc_plus4_f, 2'b00}), .s(pcf[1]), .generic_result(pc_plus2_next_f_node));
  
  // Select the PC source for the next fetch or recovery path.
  mux2 #(32) pcnextspillmux_u(.d0(pc_next_f), .d1(pc_plus2_next_f_node), .s(sel_spill_next_f & ~kill_d), .generic_result(pc_spill_next_f));
  
  
  // Register the associated stage PC using the configured Hold and reset behavior.
  ffr #(32) pcplus2reg_u(clk, reset, pc_plus2_next_f_node, pc_plus2_f_node);
  // Select the PC source for the next fetch or recovery path.
  mux2 #(32) pcspillmux_u(.d0(pcf), .d1(pc_plus2_f_node), .s(sel_spill_f), .generic_result(pc_spill_f));

  
  // Select this hardware path from the active configuration.
  if (`CFG_ICACHE_SUPPORTED) begin
    wire spill_cached_f_node;
  wire spill_uncached_f_node;
    
    
    assign spill_cached_f_node = pcf[1] & ~cached_spill_ready_f;
    assign spill_uncached_f_node = pcf[1];
    assign spill_f_node = (cacheable_f ? spill_cached_f_node : spill_uncached_f_node);
  end else
    assign spill_f_node = pcf[1];
  
  
  assign take_spill_f_node = spill_f_node & ~early_compressed_f_node & ~fetch_cache_bus_hold_f & ~instr_access_fault_f;

  // Update registered pipeline or controller state on the clock edge.
  // Register the controller state; reset and transition conditions determine each update.
  always @(posedge clk)
    if (reset | kill_d)    curr_state_node <= state_ready_node;
    else curr_state_node <= next_state_node;

  // Computes combinational outputs using decoded operation and state selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @* begin
    // Decode the current controller state and select the appropriate transition.
    case (curr_state_node)
      state_ready_node: if (take_spill_f_node)                next_state_node = state_spill_node;
                   else                           next_state_node = state_ready_node;
      state_spill_node: if(hold_f)                     next_state_node = state_spill_node;
                   else                           next_state_node = state_ready_node;
      default:                                    next_state_node = state_ready_node;
    endcase
  end

  assign sel_spill_f = (curr_state_node == state_spill_node);
  assign sel_spill_next_f = (curr_state_node == state_ready_node & take_spill_f_node) | (curr_state_node == state_spill_node & fetch_cache_bus_hold_f);
  assign spill_save_f_node = (curr_state_node == state_ready_node) & take_spill_f_node & ~kill_d;

  
  // Pipeline the instruction word while honoring stage enable and clear.
  ffenr #(16) spill_instr_reg_u(clk, reset, spill_save_f_node, instr_raw_f[15:0], instr_first_half_f_node);

  
  // Select the appropriate datapath value from the available inputs.
  mux2 #(32) postspillmux_u(instr_raw_f, {instr_raw_f[15:0], instr_first_half_f_node}, sel_spill_f, post_spill_instr_raw_f);

  
  // Compute combinational control and data selections.
  // Compute the combinational outputs from the current data and control inputs.
  always @*
  if (post_spill_instr_raw_f[1:0] != 2'b11) compressed_f = 1'b1;
  else compressed_f = 1'b0;
  assign early_compressed_f_node = ~(&instr_raw_f[1:0]);

endmodule
