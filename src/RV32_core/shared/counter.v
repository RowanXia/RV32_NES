// Implements a parameterized state counter.
// Updates its value on qualified clock cycles.


module counter #(parameter WIDTH=8) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire en,  // Register update enable.
  output wire [WIDTH-1:0] q  // Registered output value.
);

  wire [WIDTH-1:0] next_count_node;

  assign next_count_node = q + 1;
  // Carry prediction/counter metadata to the next pipeline stage.
  ffenr #(WIDTH) counter_ff_u(clk, reset, en, next_count_node, q);
endmodule
