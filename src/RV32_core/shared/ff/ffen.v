// Implements an edge-triggered register with clock enable.
// Holds its previous value while enable is inactive.


module ffen #(parameter WIDTH = 8) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire en,  // Register update enable.
  input wire [WIDTH-1:0] d,  // Value sampled by the register.
  output reg [WIDTH-1:0] q);  // Registered output value.

  // Update registered pipeline or controller state on the clock edge.
  // Clock the q state under the specified reset and enable conditions.
  always @(posedge clk)
    if (en) q <= d;
endmodule
