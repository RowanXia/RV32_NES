// Transfers a control signal through clocked synchronization stages.
// Reduces direct asynchronous observation by downstream logic.


module synchronizer (
  input wire clk,  // Clock used for synchronous state updates.
  input wire d,  // Value sampled by the register.
  output reg q);  // Registered output value.

  reg first_stage_q_node;

  // Update registered pipeline or controller state on the clock edge.
  // Clock the first_stage_q, q state under the specified reset and enable conditions.
  always @(posedge clk) begin
    first_stage_q_node <= d;
    q <= first_stage_q_node;
  end
endmodule
