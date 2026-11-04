// Extracts load data from a bus word and applies the selected extension.
// Honors byte position, load size, and signedness.


`include "config.vh"

module load_format    (
   input wire [31:0] read_data_word_mux_m,  // Data returned by the selected source.
   input wire [1:0] p_adr_m,  // Address operand or decoded address field.
   input wire [2:0] funct3_m,  // Function-3 used by the memory-stage datapath or control.
   output reg [31:0] read_data_m  // Data returned by the selected source.
);

  wire [7:0] selected_byte_m_node;
  wire [15:0] selected_halfword_m_node;

  
  // Select the appropriate datapath value from the available inputs.
  mux2 #(8)  bytemux_u(selected_halfword_m_node[7:0], selected_halfword_m_node[15:8], p_adr_m[0], selected_byte_m_node);
  // Select the appropriate datapath value from the available inputs.
  mux2 #(16) halfwordmux_u(read_data_word_mux_m[15:0], read_data_word_mux_m[31:16], p_adr_m[1], selected_halfword_m_node);

  
  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    // Select the datapath operation from the decoded instruction function field.
    case(funct3_m)
      3'b000:  read_data_m = {{24{selected_byte_m_node[7]}}, selected_byte_m_node};              
      3'b001:  read_data_m = {{16{selected_halfword_m_node[15]}}, selected_halfword_m_node};     
      3'b010:  read_data_m = read_data_word_mux_m;                     
      3'b100:  read_data_m = {24'b0, selected_byte_m_node};                       
      3'b101:  read_data_m = {16'b0, selected_halfword_m_node};                   
      default: read_data_m = read_data_word_mux_m;
    endcase
endmodule
