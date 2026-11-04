// Defines reusable 2:1, 3:1, and 4:1 data selectors.
// Selects one data word using the corresponding control bits.


/* verilator lint_off DECLFILENAME */

module mux2 #(parameter WIDTH = 8) (
  input wire [WIDTH-1:0] d0,  // Data input 0 to the selection network.
  input wire [WIDTH-1:0] d1,  // Data input 1 to the selection network.
  input wire s,  // Selects the active data input.
  output wire [WIDTH-1:0] generic_result);  // Combinational result of this parameterized utility.

  // Select input d1 when s is asserted; otherwise select d0.
  assign generic_result = s ? d1 : d0;
endmodule

module mux3 #(parameter WIDTH = 8) (
  input wire [WIDTH-1:0] d0,  // Data input 0 to the selection network.
  input wire [WIDTH-1:0] d1,  // Data input 1 to the selection network.
  input wire [WIDTH-1:0] d2,  // Data input 2 to the selection network.
  input wire [1:0] s,  // Selects the active data input.
  output wire [WIDTH-1:0] generic_result);  // Combinational result of this parameterized utility.

  // Select d2 when the high select bit is set; otherwise choose d0 or d1.
  assign generic_result = s[1] ? d2 : (s[0] ? d1 : d0); // exclusion-tag: mux3
endmodule

module mux4 #(parameter WIDTH = 8) (
  input wire [WIDTH-1:0] d0,  // Data input 0 to the selection network.
  input wire [WIDTH-1:0] d1,  // Data input 1 to the selection network.
  input wire [WIDTH-1:0] d2,  // Data input 2 to the selection network.
  input wire [WIDTH-1:0] d3,  // Data input 3 to the selection network.
  input wire [1:0] s,  // Selects the active data input.
  output wire [WIDTH-1:0] generic_result);  // Combinational result of this parameterized utility.

  // Decode both select bits to choose exactly one of the four data inputs.
  assign generic_result = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

/* verilator lint_on DECLFILENAME */
