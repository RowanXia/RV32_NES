// Counts set bits in an operand.
// Produces a combinational population-count result.


module popcnt #(parameter WIDTH = 32) (
  input wire [WIDTH-1:0] num,  // Provides num for this module.
  output wire [$clog2(WIDTH):0] pop_cnt  // Provides pop cnt for this module.
);

  reg [$clog2(WIDTH):0] sum_node;

  integer i_node;
  // Compute combinational control and data selections.
  // Compute the combinational outputs from the current data and control inputs.
  always @* begin
    sum_node = 1'b0;
    // Apply the same combinational operation to each configured element.
    for (i_node=0;i_node<WIDTH;i_node=i_node+1) begin : loop_node
      sum_node = (num[i_node]) ? sum_node + 1 : sum_node;
    end
  end

  assign pop_cnt = sum_node;
endmodule
