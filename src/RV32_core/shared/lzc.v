// Counts leading zero bits in a vector.
// Supplies the encoded leading-zero count.


module lzc #(parameter WIDTH = 1) (
  input wire [WIDTH-1:0] num,  // Provides num for this module.
  output reg [$clog2(WIDTH+1)-1:0] zero_cnt  // Provides zero cnt for this module.
);

  integer i_node;

  // Compute combinational control and data selections.
  // Compute the combinational outputs from the current data and control inputs.
  always @* begin
    i_node = 0;
    
    while ((i_node < WIDTH) && (!num[WIDTH-1-i_node])) begin
      i_node = i_node + 1;
    end
    zero_cnt = i_node[$clog2(WIDTH+1)-1:0];
  end
endmodule
