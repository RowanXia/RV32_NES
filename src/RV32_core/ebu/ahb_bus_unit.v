// Multiplexes instruction and data requests onto the processor AHB master port.
// Routes completion and error responses to the originating request path.


`include "config.vh"

module ahb_bus_unit    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  
  input wire [1:0] fetch_htrans,  // Instruction-fetch request, response, or control.
  input wire [2:0] fetch_hsize,  // Instruction-fetch request, response, or control.
  input wire [2:0] fetch_hburst,  // Instruction-fetch request, response, or control.
  input wire [31:0] fetch_haddr,  // Instruction-fetch request, response, or control.
  output wire fetch_hready,  // Completion handshake returned to the instruction fetch path.
  output wire fetch_hresp,  // Transfer error indication for instruction fetch.
  
  input wire [1:0] memory_htrans,  // Load/store memory interface or pipeline control.
  input wire memory_hwrite,  // Load/store memory interface or pipeline control.
  input wire [2:0] memory_hsize,  // Load/store memory interface or pipeline control.
  input wire [2:0] memory_hburst,  // Load/store memory interface or pipeline control.
  input wire [31:0] memory_haddr,  // Load/store memory interface or pipeline control.
  input wire [31:0] memory_hwdata,  // Load/store memory interface or pipeline control.
  input wire [3:0] memory_hwstrb,  // Load/store memory interface or pipeline control.
  output wire memory_hready,  // Completion handshake returned to the load/store path.
  output wire memory_hresp,  // Transfer error indication for the load/store path.

  
  output wire hclk,  // Clock forwarded to the AHB interface.
  output wire hrese_tn,  // Active-low AHB reset generated from the core reset.
  input wire hready,  // AHB transfer-completion handshake from the selected slave.
  input wire hresp,  // AHB response status returned by the selected slave.
  output wire [31:0] haddr,  // AHB byte address of the active bus transfer.
  output wire [31:0] hwdata,  // AHB write-data bus.
  output wire [3:0] hwstrb,  // Byte-lane strobes for the AHB write transaction.
  output wire hwrite,  // Indicates an AHB write transfer.
  output wire [2:0] hsize,  // AHB transfer size encoding.
  output wire [2:0] hburst,  // AHB burst-type encoding.
  output wire [3:0] hprot,  // AHB protection attributes.
  output wire [1:0] htrans,  // AHB transfer type for the selected bus request.
  output wire hmastlock  // AHB locked-sequence indicator.
);

  wire memory_disable;
  wire memory_select;
  wire fetch_save;
  wire fetch_restore;
  wire fetch_disable;
  wire fetch_select;

  wire [31:0] fetch_haddr_out_node;
  wire [1:0] fetch_htrans_out_node;
  wire [2:0] fetch_hburst_out_node;
  wire [2:0] fetch_hsize_out_node;
  wire fetch_hwrite_out_node;

  wire [31:0] memory_haddr_out_node;
  wire [1:0] memory_htrans_out_node;
  wire [2:0] memory_hburst_out_node;
  wire [2:0] memory_hsize_out_node;
  wire memory_hwrite_out_node;

  wire fetch_request;
  wire memory_request;
  reg response_fetch_q_node;
  reg response_mem_q_node;
  wire fetch_hready_raw_node;
  wire memory_hready_raw_node;
  wire [1:0] selected_htrans_node;
  wire ahb_error_first_cycle_node;
  wire abort_done;
  reg abort_pending_q_node;

  // Forward the CPU bus clock and derive the AHB active-low reset.
  assign hclk = clk;
  assign hrese_tn = ~reset;

  
  // Fetch buffering preserves address and control during bus arbitration.
  // Keep a pending AHB request stable while the target is not ready.
  ahb_request_buffer fetch_request_buffer_u(.hclk(hclk), .hrese_tn(hrese_tn), .save(fetch_save), .restore(fetch_restore), .disable_request(fetch_disable),
    .request(fetch_request),
    .hwrite_in(1'b0), .hsize_in(fetch_hsize), .hburst_in(fetch_hburst), .HTRANSIn(fetch_htrans), .haddr_in(fetch_haddr),
    .hwrite_out(fetch_hwrite_out_node), .hsize_out(fetch_hsize_out_node), .hburst_out(fetch_hburst_out_node), .hready_out(fetch_hready_raw_node),
    .HTRANSOut(fetch_htrans_out_node), .haddr_out(fetch_haddr_out_node), .hready_in(hready));

  
  // Data-side request buffering keeps pending AHB transfers stable.
  // Keep a pending AHB request stable while the target is not ready.
  ahb_request_buffer #(.SAVE_ENABLED(0)) memory_request_buffer_u(.hclk(hclk), .hrese_tn(hrese_tn), .save(1'b0), .restore(1'b0), .disable_request(memory_disable),
    .request(memory_request),
    .hwrite_in(memory_hwrite), .hsize_in(memory_hsize), .hburst_in(memory_hburst), .HTRANSIn(memory_htrans), .haddr_in(memory_haddr), .hready_out(memory_hready_raw_node),
    .hwrite_out(memory_hwrite_out_node), .hsize_out(memory_hsize_out_node), .hburst_out(memory_hburst_out_node),
    .HTRANSOut(memory_htrans_out_node), .haddr_out(memory_haddr_out_node), .hready_in(hready));

  
  // The selected master determines address, size, burst, and transfer type.
  // Select the active request address, size, and burst control from fetch or data.
  assign haddr = memory_select ? memory_haddr_out_node : fetch_select ? fetch_haddr_out_node : 1'b0;
  assign hsize = memory_select ? memory_hsize_out_node : fetch_select ? fetch_hsize_out_node: 1'b0;
  assign hburst = memory_select ? memory_hburst_out_node : fetch_select ? fetch_hburst_out_node : 1'b0; 
  assign selected_htrans_node = memory_select ? memory_htrans_out_node : fetch_select ? fetch_htrans_out_node: 2'b00;
  
  
  // An outstanding abort forces an IDLE transfer until recovery completes.
  // Drive IDLE while abort recovery is pending; otherwise issue the selected transfer.
  assign htrans = abort_pending_q_node ? 2'b00 : selected_htrans_node;
  assign hwrite = memory_select ? memory_hwrite_out_node : 1'b0;
  assign hprot = {3'b001, memory_select}; 
  assign hmastlock = 1'b0; 

  
  assign hwdata = memory_hwdata;
  assign hwstrb = memory_hwstrb;
  

  // Update registered pipeline or controller state on the clock edge.
  // Clock the response_fetch_q, response_mem_q state under the specified reset and enable conditions.
  always @(posedge hclk)
    if (~hrese_tn) begin
      response_fetch_q_node <= 1'b0;
      response_mem_q_node <= 1'b0;
    end else if (hready) begin
      response_fetch_q_node <= fetch_select & htrans[1];
      response_mem_q_node <= memory_select & htrans[1];
    end

  // Route the AHB response status back to the originating request.
  assign fetch_hresp = hresp & response_fetch_q_node;
  assign memory_hresp = hresp & response_mem_q_node;

  assign ahb_error_first_cycle_node = hresp & ~hready & (response_fetch_q_node | response_mem_q_node);
  assign abort_done = abort_pending_q_node & hready & hresp;
  // Updates sequential state on the specified clock event.
  // Clock the abort_pending_q, abort_pending_q state under the specified reset and enable conditions.
  always @(posedge hclk)
    if (~hrese_tn)             abort_pending_q_node <= 1'b0;
    else if (ahb_error_first_cycle_node)   abort_pending_q_node <= 1'b1;
    else if (hready)          abort_pending_q_node <= 1'b0;

  // Qualify transfer completion with the bus handshake.
  assign fetch_hready = abort_pending_q_node ? (hready & response_fetch_q_node) : fetch_hready_raw_node;
  assign memory_hready = abort_pending_q_node ? (hready & response_mem_q_node) : memory_hready_raw_node;

  // Select the active AHB requester and hold ownership through the transfer handshake.
  ahb_arbiter_fsm ahb_arbiter_fsm_i_u(.hclk(hclk), .hrese_tn(hrese_tn), .hburst(hburst), .hready(hready), .abort_done(abort_done), .memory_request(memory_request), .fetch_request(fetch_request), .fetch_save(fetch_save),
          .fetch_restore(fetch_restore), .fetch_disable(fetch_disable), .fetch_select(fetch_select), .memory_disable(memory_disable), .memory_select(memory_select));

endmodule
