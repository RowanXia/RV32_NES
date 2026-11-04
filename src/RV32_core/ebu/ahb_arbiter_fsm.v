// Arbitrates AHB ownership between instruction fetch and data memory requests.
// Retains transaction ownership until the applicable handshake permits a change.


module ahb_arbiter_fsm (
  input wire hclk,  // Clock forwarded to the AHB interface.
  input wire hrese_tn,  // Active-low AHB reset generated from the core reset.
  input wire [2:0] hburst,  // AHB burst-type encoding.
 

  input wire hready,  // AHB transfer-completion handshake from the selected slave.
  input wire abort_done,  // Provides abort done for this module.

  input wire memory_request,  // Load/store memory interface or pipeline control.
  input wire fetch_request,  // Instruction-fetch request, response, or control.

  output wire fetch_save,  // Instruction-fetch request, response, or control.
  output wire fetch_restore,  // Instruction-fetch request, response, or control.
  output wire fetch_disable,  // Instruction-fetch request, response, or control.
  output wire fetch_select,  // Instruction-fetch request, response, or control.
  output wire memory_disable,  // Load/store memory interface or pipeline control.
  output wire memory_select);  // Load/store memory interface or pipeline control.

    localparam [1:0] idle_node = 2'd0;
  localparam [1:0] arbitrate_node = 2'd1;
  wire [1:0] curr_state_node;
  reg [1:0] next_state_node;

  wire both_requests_node;                       
  wire fetch_request_delayed_node;                    
  wire final_beat_node;
  wire final_beat_data_phase_node;      
  wire beat_counter_enable_node;
  wire [3:0] beat_count;                  
  wire beat_counter_reset_node;
  reg [3:0] final_beat_index_node;                  

  
  assign both_requests_node = memory_request & fetch_request;
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenl #(.WIDTH(2)) busreg_u(hclk, ~hrese_tn, 1'b1, next_state_node, idle_node, curr_state_node);
  // Maintain AHB ownership while a transfer is outstanding.
  // Computes combinational outputs using decoded operation and state selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    // Select control behavior for the decoded state or operation.
    // Decode the current controller state and select the appropriate transition.
    case (curr_state_node)
      idle_node:      if (abort_done)                                 next_state_node = idle_node;
                 else if (both_requests_node)                                 next_state_node = arbitrate_node;
                 else                                           next_state_node = idle_node;
      arbitrate_node: if (abort_done)                                 next_state_node = idle_node;
                 else if (hready & final_beat_data_phase_node & ~both_requests_node)          next_state_node = idle_node;
                 else                                           next_state_node = arbitrate_node;
      default:                                                  next_state_node = idle_node;
    endcase

  
  assign fetch_save = curr_state_node == idle_node & both_requests_node;
  assign fetch_restore = curr_state_node == arbitrate_node;
  assign fetch_disable = fetch_restore;
  assign fetch_select = (next_state_node == arbitrate_node) ? 1'b0 : fetch_request;
  
  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffr #(1) fetch_request_reg_u(hclk, ~hrese_tn | abort_done, fetch_request, fetch_request_delayed_node);
  assign memory_disable = (curr_state_node != arbitrate_node) & fetch_request_delayed_node;
  assign memory_select = (next_state_node == arbitrate_node) ? 1'b1: memory_request;

  
  // Form the counter update value from the current event or state.
  assign beat_counter_reset_node = (next_state_node == idle_node) | abort_done;
  assign final_beat_node = (beat_count == final_beat_index_node); 
  
  
  assign beat_counter_enable_node = (next_state_node == arbitrate_node) & hready & ~abort_done;
  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(1) final_beat_reg_u(hclk, ~hrese_tn | beat_counter_reset_node, beat_counter_enable_node, final_beat_node, final_beat_data_phase_node);

  // Carry prediction/counter metadata to the next pipeline stage.
  counter #(4) beat_counter_u(hclk, ~hrese_tn | beat_counter_reset_node | final_beat_node, beat_counter_enable_node, beat_count);

  
  // Compute combinational control and data selections.
  // Compute the combinational outputs from the current data and control inputs.
  always @*
    if (hburst[2:1] == 2'b00) final_beat_index_node = 4'b0000;
    else                      final_beat_index_node = ('d2 << hburst[2:1]) - 'd1;

endmodule
