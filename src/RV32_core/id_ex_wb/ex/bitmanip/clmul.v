// Computes carry-less multiplication partial products.
// Forms the polynomial product without arithmetic carry propagation.


module clmul #(parameter WIDTH=32) (
  input wire [WIDTH-1:0] x,  // Provides x for this module.
  input wire [WIDTH-1:0] operation_result,  // Provides operation result for this module.
  output reg [WIDTH-1:0] clmul_result);  // Provides clmul result for this module.

  reg [(WIDTH*WIDTH)-1:0] s_node;               

  integer i_node,j;

  // Compute combinational control and data selections.
  // Compute the combinational outputs from the current data and control inputs.
  always @* begin
    // Apply the same combinational operation to each configured element.
    for (i_node=0;i_node<WIDTH;i_node = i_node + 1) begin : outer
      s_node[WIDTH*i_node] = x[0] & operation_result[i_node];
      // Apply the same combinational operation to each configured element.
      for (j=1;j<=i_node;j = j + 1) begin : inner
        s_node[WIDTH*i_node+j] = (x[j] & operation_result[i_node-j]) ^ s_node[WIDTH*i_node+j-1];
      end
      clmul_result[i_node] = s_node[WIDTH*i_node+j-1];
    end
  end
endmodule
