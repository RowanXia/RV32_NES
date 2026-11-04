// Stores the architectural integer registers and serves operand reads.
// Applies qualified writeback updates while preserving the zero register behavior.


module register_file (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire we3,  // Provides we3 for this module.
  input wire [4:0] a1,  // Provides a1 for this module.
  input wire [4:0] a2,  // Provides a2 for this module.
  input wire [4:0] a3,  // Provides a3 for this module.
  input wire [31:0] wd3,  // Provides wd3 for this module.
  output wire [31:0] rd1,  // Provides rd1 for this module.
  output wire [31:0] rd2);  // Provides rd2 for this module.

  reg [31:0] rf_node[31:1];
  integer i_node;

  
  // Update registered pipeline or controller state on the clock edge.
  // Update sequential state on the active clock edge, respecting reset and enables.
  always @(negedge clk)
    if (reset) for(i_node=1; i_node<32; i_node = i_node + 1) rf_node[i_node] <= 1'b0;
    else       if (we3)                 rf_node[a3] <= wd3;

  assign rd2 = (a2 != 0) ? rf_node[a2] : 0;
  assign rd1 = (a1 != 0) ? rf_node[a1] : 0;
endmodule
