// Implements a register with reset, clear, and update controls.
// Applies control priority at the active clock edge.


module ffenrc #(parameter WIDTH = 8) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire clear,  // Provides clear for this module.
  input wire en,  // Register update enable.
  input wire [WIDTH-1:0] d,  // Value sampled by the register.
  output reg [WIDTH-1:0] q);  // Registered output value.

  // Update registered pipeline or controller state on the clock edge.
  // Clock the q, q state under the specified reset and enable conditions.
  always @(posedge clk)
    if (reset)   q <= 1'b0;
    else if (en)
      if (clear) q <= 1'b0;
      else       q <= d;
endmodule
