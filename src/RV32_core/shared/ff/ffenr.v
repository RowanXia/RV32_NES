// Implements an enabled register with synchronous reset.
// Prioritizes reset over a qualified data update.


module ffenr #(parameter WIDTH = 8) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire en,  // Register update enable.
  input wire [WIDTH-1:0] d,  // Value sampled by the register.
  output reg [WIDTH-1:0] q);  // Registered output value.

  // Update registered pipeline or controller state on the clock edge.
  // Clock the q, q state under the specified reset and enable conditions.
  always @(posedge clk)
    if (reset)   q <= 1'b0;
    else if (en) q <= d;
endmodule
