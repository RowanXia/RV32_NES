// Reduces multiple input rows into a bitwise OR result.
// Combines matching bit positions across all rows.


module or_rows #(parameter ROWS = 8, COLS=2) (
  input wire [ROWS*COLS-1:0] generic_input_a,  // First input data word for the combinational operation.
  output wire [COLS-1:0] generic_result  // Combinational result of this parameterized utility.
  );

  genvar row;

  if(ROWS == 1)
    assign generic_result = generic_input_a[(0)*COLS +: COLS];
  else begin
    /* verilator lint_off UNOPTFLAT */
    wire [COLS-1:0] mid_node[ROWS-1:1];

    assign mid_node[1] = generic_input_a[(0)*COLS +: COLS] | generic_input_a[(1)*COLS +: COLS];
    // Apply the same combinational operation to each configured element.
    for (row=2; row < ROWS; row = row + 1)
      assign mid_node[row] = mid_node[row-1] | generic_input_a[(row)*COLS +: COLS];
    assign generic_result = mid_node[ROWS-1];
    /* verilator lint_on UNOPTFLAT */
  end
endmodule
