// Module role: Implements machine software and timer interrupt control registers.
// Behavioral interface: MSIP, MTIMECMP, and MTIME drive interrupt outputs; MTIME increments on PCLK.

`include "../config.vh"

module clint_apb    (
  input wire pclk_link,
  input wire prese_tn_link,
  input wire psel_link,
  input wire [15:0] paddr_link,
  input wire [31:0] pwdata_link,
  input wire [3:0] pstrb_link,
  input wire pwrite_link,
  input wire penable_link,
  output reg [31:0] prdata_link,
  output wire pready_link,
  output reg [63:0] mtime_link,
  output wire m_timer_int_link,
  output wire m_sw_int_link
);

  // register map
  localparam clint_msip_node     = 16'h0000;
  localparam clint_mtimecmp_node = 16'h4000;
  localparam clint_mtime_node    = 16'hBFF8;

  reg msip_node;
  wire [15:0] entry_node;
  wire memwrite_node;
  reg [63:0] mtimecmp_node;
  integer                     i_node;

  assign memwrite_node = pwrite_link & penable_link & psel_link;  // only write in access phase
  assign pready_link   = 1'b1;                     // CLINT never takes >1 cycle to respond

  assign entry_node = {paddr_link[15:2], 2'b00};

  // MTIME increments on PCLK.  In this SoC the APB bridge uses HCLK as PCLK;
  // there is no independent timer clock or cross-domain synchronization.

  always @(posedge pclk_link)
    if (~prese_tn_link) begin
      msip_node <= 1'b0;
      mtimecmp_node <= 64'hFFFFFFFFFFFFFFFF;
    end else if (memwrite_node) begin
      if ((entry_node == clint_msip_node) & pstrb_link[0]) msip_node <= pwdata_link[0];
      if (entry_node == clint_mtimecmp_node)
        for (i_node=0; i_node<4; i_node = i_node + 1)
          if (pstrb_link[i_node]) mtimecmp_node[i_node*8 +:8] <= pwdata_link[i_node*8 +:8];
      if (entry_node == clint_mtimecmp_node + 4)
        for (i_node=0; i_node<4; i_node = i_node + 1)
          if (pstrb_link[i_node]) mtimecmp_node[32 + i_node*8 +:8] <= pwdata_link[i_node*8 +:8];
    end

  always @(posedge pclk_link)
    if (~prese_tn_link) begin
      mtime_link <= 1'b0;
    end else if (memwrite_node & (entry_node == clint_mtime_node)) begin
      for (i_node=0; i_node<4; i_node = i_node + 1)
        if (pstrb_link[i_node]) mtime_link[i_node*8 +:8] <= pwdata_link[i_node*8 +:8];
    end else if (memwrite_node & (entry_node == clint_mtime_node + 4)) begin
      for (i_node=0; i_node<4; i_node = i_node + 1)
        if (pstrb_link[i_node]) mtime_link[32 + i_node*8 +:8] <= pwdata_link[i_node*8 +:8];
    end else mtime_link <= mtime_link + 1;

  // Register the APB read response independently of the timer state updates.
  always @(posedge pclk_link) begin
    case(entry_node)
      16'h0000: prdata_link <= {31'b0, msip_node};
      16'h4000: prdata_link <= mtimecmp_node[31:0];
      16'h4004: prdata_link <= mtimecmp_node[63:32];
      16'hBFF8: prdata_link <= mtime_link[31:0];
      16'hBFFC: prdata_link <= mtime_link[63:32];
      default:  prdata_link <= 1'b0;
    endcase
  end

  // Software interrupt when MSIP is set
  assign m_sw_int_link = msip_node;
  // Timer interrupt when MTIME >= MTIMECMP
  assign m_timer_int_link = ({1'b0, mtime_link} >= {1'b0, mtimecmp_node}); // unsigned comparison

endmodule
