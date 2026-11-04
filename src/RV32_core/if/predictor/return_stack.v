// Predicts return targets using a return-address stack.
// Tracks call/return operations and repairs stack state on control-flow changes.


`include "config.vh"

module return_stack   (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  output wire [32-1:0] return_stack_target_f,  // Return stack target used by the fetch-stage datapath or control.
  input wire DecodeHold,  // Holds predictor metadata associated with decode.
  input wire ExecuteHold,  // Holds predictor metadata associated with execute.
  input wire MemoryHold /* synthesis PAP_MARK_DEBUG="true" */,  // Holds predictor metadata associated with memory.
  input wire DecodeKill /* synthesis PAP_MARK_DEBUG="true" */,  // Invalidates predictor metadata following decode cancellation.
  input wire ExecuteKill,  // Invalidates execute-stage predictor metadata.
  input wire MemoryKill,  // Invalidates memory-stage predictor metadata.
  input wire return_class_wrong_d,  // Return class mismatch status observed in the decode stage.
  input wire predicted_return_d,  // Predicted return used by the decode-stage datapath or control.
  input wire return_d,  // Return used by the decode-stage datapath or control.
  input wire return_e,  // Return used by the execute-stage datapath or control.
  input wire call_e,  // Call used by the execute-stage datapath or control.
  input wire predicted_return_f,  // Predicted return used by the fetch-stage datapath or control.
  input wire [32-1:0] link_address_e  // Address operand or target address selection.
   );

  wire pointer_update_en_node;
  // 32 return addresses, each 32 bits wide.  The five-bit pointer wraps
  // naturally on overflow, preserving the existing circular-stack policy.
  localparam integer depth_node = 5;

  wire [depth_node-1:0] pointer_next_node;
  wire [depth_node-1:0] pointer_node;
  wire [depth_node-1:0] increment_one_node;
  wire [depth_node-1:0] decrement_one_node;
  wire [depth_node-1:0] pointer_step_node;
  reg [32-1:0] memory_node [0:32-1];
  integer        index;

  wire predicted_pop_f_node;
  wire resolved_push_e_node;
  wire pointer_repair_d_node;
  wire increment_repair_d_node;
  wire decrement_repair_d_node;

  wire decrement_pointer_node;
  wire killed_return_de_node;
  wire wrong_pred_return_d_node;

  assign predicted_pop_f_node = predicted_return_f & ~DecodeHold & ~DecodeKill;
  assign resolved_push_e_node = call_e & ~MemoryHold & ~MemoryKill;

  assign wrong_pred_return_d_node = (return_class_wrong_d) & ~ExecuteHold & ~ExecuteKill;
  
  
  // Qualify pipeline cancellation using redirect or invalidation conditions.
  assign killed_return_de_node = (~DecodeHold & ExecuteKill & predicted_return_d) | (~ExecuteHold & MemoryKill & return_e);

  assign pointer_repair_d_node = wrong_pred_return_d_node | killed_return_de_node ;

  assign increment_repair_d_node = killed_return_de_node | (wrong_pred_return_d_node & ~return_d); 

  assign decrement_repair_d_node =  wrong_pred_return_d_node & return_d; 

  assign pointer_update_en_node = predicted_pop_f_node | resolved_push_e_node | pointer_repair_d_node;

  assign decrement_pointer_node = (predicted_pop_f_node | decrement_repair_d_node) & ~increment_repair_d_node;

  assign increment_one_node = 1;
  assign decrement_one_node = {depth_node{1'b1}}; 
  // Select the appropriate datapath value from the available inputs.
  mux2 #(depth_node) ptr_mux_u(increment_one_node, decrement_one_node, decrement_pointer_node, pointer_step_node);
  wire [depth_node-1:0] pointer_sum_node;
  assign pointer_sum_node = pointer_node + pointer_step_node;
  
  assign pointer_next_node = pointer_sum_node;


  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(depth_node) ptrreg_u(clk, reset, pointer_update_en_node, pointer_next_node, pointer_node);

  
  // Track call and return addresses under pipeline control.
  // Updates sequential state on the specified clock event.
  // Update sequential state on the active clock edge, respecting reset and enables.
  always @ (posedge clk) begin
    if(reset) begin
      // Apply the same combinational operation to each configured element.
      for(index=0; index<32; index = index + 1)
    memory_node[index] <= {32{1'b0}};
    end else if(resolved_push_e_node) begin
      memory_node[pointer_next_node] <= link_address_e;
    end
  end

  // Qualify transfer completion with the bus handshake.
  assign return_stack_target_f = memory_node[pointer_node];


endmodule
