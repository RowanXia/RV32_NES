// AHB-Lite termination for an address window whose peripheral is disabled.
// It returns the required two-cycle ERROR response and never accepts writes.
module ahb_disabled_slave (
  input  wire clk,
  input  wire reset_n,
  input  wire select_link,
  input  wire [1:0] transfer_link,
  input  wire ready_link,
  output wire [31:0] read_data_link,
  output wire ready_out_link,
  output wire response_link
);
  localparam [1:0] IDLE = 2'd0, ERROR_WAIT = 2'd1, ERROR_DONE = 2'd2;
  reg [1:0] state_node;
  wire accepted_node = select_link & transfer_link[1] & ready_link;

  always @(posedge clk or negedge reset_n)
    if (!reset_n) state_node <= IDLE;
    else case (state_node)
      IDLE:       state_node <= accepted_node ? ERROR_WAIT : IDLE;
      ERROR_WAIT: state_node <= ERROR_DONE;
      ERROR_DONE: state_node <= IDLE;
      default:    state_node <= IDLE;
    endcase

  assign read_data_link = 32'b0;
  assign response_link  = state_node != IDLE;
  assign ready_out_link = state_node != ERROR_WAIT;
endmodule
