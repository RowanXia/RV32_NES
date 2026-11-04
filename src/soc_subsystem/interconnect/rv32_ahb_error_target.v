// Two-cycle AHB-Lite ERROR target used to guard the slow matrix's former
// program-RAM window.  The real 48-KiB RAM is local to the CPU clock domain.
module rv32_ahb_error_target (
  input  wire       clk,
  input  wire       reset_n,
  input  wire       hsel,
  input  wire [1:0] htrans,
  input  wire       hready,
  output wire [31:0] hrdata,
  output wire       hreadyout,
  output wire       hresp
);
  localparam [1:0] IDLE = 2'd0;
  localparam [1:0] ERR1 = 2'd1;
  localparam [1:0] ERR2 = 2'd2;
  reg [1:0] state;

  wire accept = hsel && htrans[1] && hready;
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n)
      state <= IDLE;
    else begin
      case (state)
        IDLE: state <= accept ? ERR1 : IDLE;
        ERR1: state <= ERR2;
        ERR2: state <= IDLE;
        default: state <= IDLE;
      endcase
    end
  end

  assign hrdata = 32'b0;
  assign hreadyout = state != ERR1;
  assign hresp = state != IDLE;
endmodule
