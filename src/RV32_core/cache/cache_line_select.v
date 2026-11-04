// Selects cache-line fields, refill data, and requested word positions.
// Keeps data selection consistent with line address and access size.


module cache_line_select #(parameter linelen_node = 128, WORDLEN = 32,
  parameter MUXINTERVAL = 32 )(     
  input wire [$clog2(linelen_node/8) - $clog2(MUXINTERVAL/8) - 1 : 0] p_adr,  // Set index used for replacement metadata updates.
  input wire [linelen_node-1:0] read_data_line,  // Data returned by the selected source.
  output wire [WORDLEN-1:0] read_data_word  // Data returned by the selected source.
);

  localparam wordsperline_node = linelen_node/MUXINTERVAL;
  localparam padlen_node = WORDLEN-MUXINTERVAL;

  
  wire [linelen_node+(WORDLEN-MUXINTERVAL)-1:0] read_data_line_pad_node;
  wire [WORDLEN-1:0] read_data_line_sets_node [(linelen_node/MUXINTERVAL)-1:0];

  if (padlen_node > 0) assign read_data_line_pad_node = {{padlen_node{1'b0}}, read_data_line};
  else            assign read_data_line_pad_node = read_data_line;

  genvar index;
  // Apply the same combinational operation to each configured element.
  for (index = 0; index < wordsperline_node; index = index + 1) begin : readdatalinesetsmux
    assign read_data_line_sets_node[index] = read_data_line_pad_node[(index*MUXINTERVAL)+WORDLEN-1 : (index*MUXINTERVAL)];
  end

  
  assign read_data_word = read_data_line_sets_node[p_adr];
endmodule
