// Executes one step of the division recurrence.
// Updates partial remainder and quotient information.


module division_step (
  input wire [31:0] w,  // Provides w for this module.
  input wire [31:0] xq,  // Provides xq for this module.
  input wire [31:0] d_abs_b,  // Provides d abs b for this module.
  output wire [31:0] w_out,  // Provides w out for this module.
  output wire [31:0] xq_out  // Provides xq out for this module.
);

  wire [31:0] w_shift_node;       
  wire [31:0] w_prime_node;       
  wire qi_node;
  wire qib_node;                  

  assign {w_shift_node, xq_out} = {w[30:0], xq, qi_node};  
  // Compute a parameterized arithmetic sum.
  adder #(32+1) wdsub_u({1'b0, w_shift_node}, {1'b1, d_abs_b}, {qib_node, w_prime_node}); 
  assign qi_node = ~qib_node;
  // Select the appropriate datapath value from the available inputs.
  mux2 #(32) wrestoremux_u(w_shift_node, w_prime_node, qi_node, w_out); 
endmodule
