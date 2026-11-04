// Implements a parameterized edge-triggered register.
// Captures its input on the active clock edge.


module ff #(parameter WIDTH = 8) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire [WIDTH-1:0] d,  // Value sampled by the register.
  output reg [WIDTH-1:0] q);  // Registered output value.

  // Update registered pipeline or controller state on the clock edge.
  // Clock the q state under the specified reset and enable conditions.
  always @(posedge clk)
    q <= d;
endmodule
