// Sequences multi-cycle integer division and remainder operations.
// Tracks iteration state, signed operands, completion, and result selection.


`include "config.vh"

module divider    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire kill_e,  // Cancels younger execute-stage work or injects a bubble.
  input wire int_div_e,  // Selects integer division/remainder operations in execute.
  input wire div_signed_e,  // Division signed used by the execute-stage datapath or control.
  input wire [31:0] forwarded_src_ae,  // Operand value after bypass/forwarding selection.
  input wire [31:0] forwarded_src_be,  // Operand value after bypass/forwarding selection.
  output wire div_busy_e,  // Indicates an outstanding iterative division.
  output wire [31:0] quot_m,  // Quot used by the memory-stage datapath or control.
  output wire [31:0] rem_m  // Rem used by the memory-stage datapath or control.
 );

  localparam stepbits_node = $clog2((32'd32)/`CFG_IDIV_BITSPERCYCLE); 

  
  localparam [1:0] idle_node = 2'd0;
  localparam [1:0] busy_node = 2'd1;
  localparam [1:0] done_node = 2'd2;
  reg [1:0] state_node;

  wire [31:0] w[`CFG_IDIV_BITSPERCYCLE:0];            
  wire [31:0] xq[`CFG_IDIV_BITSPERCYCLE:0];           
  wire [31:0] w_next_node;
  wire [31:0] xq_next_node;                       
  wire [31:0] din_e_node;
  wire [31:0] xin_e_node;                          
  wire [31:0] dn_e_node;                                 
  wire [31:0] d_abs_be_node;                              
  wire [31:0] d_abs_b;                               
  wire [31:0] xn_e_node;                                 
  wire [31:0] x_init_e_node;                              
  wire [31:0] wn_m_node;
  wire [31:0] x_qn_m_node;                           
  reg [stepbits_node:0] step;                                
  wire div0_e_node;
  wire div0_m_node;                        
  wire div_start_e_node;                           
  wire sign_xe_node;
  wire sign_de_node;                      
  wire neg_qe_node;
  wire neg_wm_node;
  wire neg_qm_node;                 

  
  assign div_start_e_node = int_div_e & (state_node == idle_node) & ~hold_m;
  assign div_busy_e = (state_node == busy_node) | div_start_e_node;

  assign xin_e_node = forwarded_src_ae;
  assign din_e_node = forwarded_src_be;

  
  assign sign_de_node = div_signed_e & din_e_node[31];
  assign sign_xe_node = div_signed_e & xin_e_node[31];
  assign neg_qe_node = sign_de_node ^ sign_xe_node;
  assign div0_e_node = (din_e_node == 0);

  
  // Compute the two-complement negation of an operand.
  neg #(32) negx_u(xin_e_node, xn_e_node);
  // Select the appropriate datapath value from the available inputs.
  mux3 #(32) xabsmux_u(xin_e_node, xn_e_node, forwarded_src_ae, {div0_e_node, sign_xe_node}, x_init_e_node);  
  // Compute the two-complement negation of an operand.
  neg #(32) negd_u(din_e_node, dn_e_node);
  // Select the appropriate datapath value from the available inputs.
  mux2 #(32) dabsmux_u(dn_e_node, din_e_node, sign_de_node, d_abs_be_node);  

  
  // Select the appropriate datapath value from the available inputs.
  mux2 #(32) wmux_u(w[`CFG_IDIV_BITSPERCYCLE], {32{1'b0}}, div_start_e_node, w_next_node);
  // Select the appropriate datapath value from the available inputs.
  mux2 #(32) xmux_u(xq[`CFG_IDIV_BITSPERCYCLE], x_init_e_node, div_start_e_node, xq_next_node);

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffen #(32) wreg_u(clk, div_busy_e, w_next_node, w[0]);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffen #(32) xreg_u(clk, div_busy_e, xq_next_node, xq[0]);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffen #(32) dabsreg_u(clk, div_start_e_node, d_abs_be_node, d_abs_b);

  
  genvar i_node;
  // Apply the same combinational operation to each configured element.
  for (i_node=0; i_node<`CFG_IDIV_BITSPERCYCLE; i_node = i_node+1)
    // Perform a single step of the iterative divide/remainder calculation.
    division_step division_step_i_u(w[i_node], xq[i_node], d_abs_b, w[i_node+1], xq[i_node+1]);

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffen #(3) div0e_m_reg_u(clk, div_start_e_node, {div0_e_node, neg_qe_node, sign_xe_node}, {div0_m_node, neg_qm_node, neg_wm_node});

  
  // Compute the two-complement negation of an operand.
  neg #(32) wneg_u(w[0], wn_m_node);
  // Compute the two-complement negation of an operand.
  neg #(32) qneg_u(xq[0], x_qn_m_node);
  
  // Select the appropriate datapath value from the available inputs.
  mux3 #(32) qmux_u(xq[0], x_qn_m_node, {32{1'b1}}, {div0_m_node, neg_qm_node}, quot_m); 
  // Select the appropriate datapath value from the available inputs.
  mux3 #(32) remmux_u(w[0], wn_m_node, xq[0], {div0_m_node, neg_wm_node}, rem_m); 

  
 // Retain division state across iterative execution cycles.
 // Register the controller state; reset and transition conditions determine each update.
 always @(posedge clk)
    if (reset | kill_e & ~hold_m) begin
        state_node <= idle_node;
    end else if (div_start_e_node) begin
        step <= 1;
        if (div0_e_node) state_node <= done_node;
        else       state_node <= busy_node;
    end else if (state_node == busy_node) begin 
        if (step[stepbits_node]) begin
            state_node <= done_node;
        end
        step <= step + 1;
    end else if (state_node == done_node) begin
      if (hold_m) state_node <= done_node;
      else        state_node <= idle_node;
    end
endmodule
