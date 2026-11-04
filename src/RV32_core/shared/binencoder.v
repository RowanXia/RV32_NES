// Converts an active input position into a binary index.
// Supplies a compact encoding of the selected bit.


module binencoder #(parameter N = 8) (
  input wire [N-1:0] primary_operand,  // First arithmetic or logical source operand.
  output reg [$clog2(N)-1:0] operation_result  // Provides operation result for this module.
);

  integer                      index;

  
  // Compute combinational control and data selections.
  // Compute the combinational outputs from the current data and control inputs.
  always @*  begin
    operation_result = 1'b0;
    // Apply the same combinational operation to each configured element.
    for(index = 0; index < N; index = index + 1)
      if(primary_operand[index] == 1'b1) operation_result = index[$clog2(N)-1:0];
  end

endmodule
