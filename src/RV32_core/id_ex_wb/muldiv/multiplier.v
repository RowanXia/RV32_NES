// Computes signed or unsigned multiplication results.
// Selects the required low or high product portion.


module multiplier (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  input wire [31:0] forwarded_src_ae,  // Operand value after bypass/forwarding selection.
  input wire [31:0] forwarded_src_be,  // Operand value after bypass/forwarding selection.
  input wire [2:0] funct3_e,  // Function-3 used by the execute-stage datapath or control.
  output wire [63:0] prod_m  // Prod used by the memory-stage datapath or control.
);

  
  wire [31:0] aprime_node;
  wire [31:0] bprime_node;                       
  wire mulh_node;
  wire mulhsu_node;                         
  wire [30:0] pa_node;
  wire [30:0] pb_node;                               
  wire pp_node;                                   
  localparam half_node = 32/2;
  wire [31:0] pp00_e_node;
  wire [31:0] pp01_e_node;
  wire [31:0] pp10_e_node;
  wire [31:0] pp11_e_node;            
  wire [31:0] pp00_m_node;
  wire [31:0] pp01_m_node;
  wire [31:0] pp10_m_node;
  wire [31:0] pp11_m_node;            
  wire [63:0] pp1_m_node;
  wire [63:0] pp2_e_node;
  wire [63:0] pp3_e_node;
  reg [63:0] pp4_e_node;               
  wire [63:0] pp2_m_node;
  wire [63:0] pp3_m_node;
  wire [63:0] pp4_m_node;                     

  
  assign aprime_node = {1'b0, forwarded_src_ae[30:0]};
  assign bprime_node = {1'b0, forwarded_src_be[30:0]};
  
  
  assign pp00_e_node = aprime_node[half_node-1:0]       * bprime_node[half_node-1:0];
  assign pp01_e_node = aprime_node[half_node-1:0]       * bprime_node[31:half_node];
  assign pp10_e_node = aprime_node[31:half_node]    * bprime_node[half_node-1:0];
  assign pp11_e_node = aprime_node[31:half_node]    * bprime_node[31:half_node];
  assign pa_node = {31{forwarded_src_ae[31]}} & forwarded_src_be[30:0];
  assign pb_node = {31{forwarded_src_be[31]}} & forwarded_src_ae[30:0];
  assign pp_node = forwarded_src_ae[31] & forwarded_src_be[31];

  
  assign mulh_node   = (funct3_e == 3'b001);
  assign mulhsu_node = (funct3_e == 3'b010);

  
  assign pp2_e_node = {2'b00, (mulh_node | mulhsu_node) ? ~pa_node : pa_node, {31{1'b0}}};
  assign pp3_e_node = {2'b00, (mulh_node) ? ~pb_node : pb_node, {31{1'b0}}};
  // Compute combinational control and data selections.
  // Compute the combinational outputs from the current data and control inputs.
  always @*
  if (mulh_node)        pp4_e_node = {1'b1, pp_node, {29{1'b0}}, 1'b1, {32{1'b0}}};
  else if (mulhsu_node) pp4_e_node = {1'b1, ~pp_node, {30{1'b0}}, 1'b1, {31{1'b0}}};
  else             pp4_e_node = {1'b0, pp_node, {62{1'b0}}};

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) pp00_reg_u(clk, reset, kill_m, ~hold_m, pp00_e_node, pp00_m_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) pp01_reg_u(clk, reset, kill_m, ~hold_m, pp01_e_node, pp01_m_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) pp10_reg_u(clk, reset, kill_m, ~hold_m, pp10_e_node, pp10_m_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) pp11_reg_u(clk, reset, kill_m, ~hold_m, pp11_e_node, pp11_m_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32*2) pp2_reg_u(clk, reset, kill_m, ~hold_m, pp2_e_node, pp2_m_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32*2) pp3_reg_u(clk, reset, kill_m, ~hold_m, pp3_e_node, pp3_m_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32*2) pp4_reg_u(clk, reset, kill_m, ~hold_m, pp4_e_node, pp4_m_node);

  assign pp1_m_node = {{32{1'b0}}, pp00_m_node}
              + {{half_node{1'b0}}, pp01_m_node, {half_node{1'b0}}}
              + {{half_node{1'b0}}, pp10_m_node, {half_node{1'b0}}}
              + {pp11_m_node, {32{1'b0}}};

  
  assign prod_m = pp1_m_node + pp2_m_node + pp3_m_node + pp4_m_node; 
 endmodule
