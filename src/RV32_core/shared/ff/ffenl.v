// Implements a parameterized enabled register with a load condition.
// Selects registered updates using the module control inputs.


module ffenl #(parameter WIDTH = 8) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire load,  // Provides load for this module.
  input wire en,  // Register update enable.
  input wire [WIDTH-1:0] d,  // Value sampled by the register.
  input wire [WIDTH-1:0] val,  // Provides val for this module.
  output reg [WIDTH-1:0] q);  // Registered output value.

  // Update registered pipeline or controller state on the clock edge.
  // Clock the q, q state under the specified reset and enable conditions.
  always @(posedge clk)
    if (load)    q <= val;
    else if (en) q <= d;
endmodule
