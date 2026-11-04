// Controls cache-line transfers over the AHB interface.
// Tracks transfer beats and completion for refills and writebacks.


module ahb_cache_fsm #(
  parameter beat_count_threshold_node = 3,                      
  parameter ahbwlogbwpl_node = 2,                             
  parameter READ_ONLY_CACHE = 0,                         
  parameter BURST_EN = 1                                 
)(
  input wire hclk,  // Clock forwarded to the AHB interface.
  input wire hrese_tn,  // Active-low AHB reset generated from the core reset.

  
  input wire hold,  // Prevents the corresponding pipeline stage from advancing.
  input wire kill,  // Cancels invalid or wrong-path pipeline work.
  input wire [1:0] bus_rw /* synthesis PAP_MARK_DEBUG="true" */,  // Provides bus rw for this module.
  output wire bus_hold,  // Prevents the corresponding pipeline stage from advancing.
  output wire bus_committed,  // Provides bus committed for this module.

  
  output wire capture_en,  // Provides capture en for this module.
  output wire cache_fetch_capture_en,  // Cache-side data, address, or operation control.
  output wire bus_error,  // Provides bus error for this module.

  
  input wire [1:0] cache_bus_rw /* synthesis PAP_MARK_DEBUG="true" */,  // External memory transaction associated with cache control.
  output wire cache_bus_ack,  // External memory transaction associated with cache control.

  
  output wire [ahbwlogbwpl_node-1:0] beat_count,  // Provides beat count for this module.
  output wire [ahbwlogbwpl_node-1:0] beat_count_delayed,  // Provides beat count delayed for this module.
  output wire sel_bus_beat,  // Provides sel bus beat for this module.

  
  input wire hready,  // AHB transfer-completion handshake from the selected slave.
  input wire hresp,  // AHB response status returned by the selected slave.
  output wire [1:0] htrans,  // AHB transfer type for the selected bus request.
  output wire hwrite,  // Indicates an AHB write transfer.
  output wire [2:0] hburst  // AHB burst-type encoding.
);

    localparam [2:0] adr_phase_node = 3'd0;
  localparam [2:0] data_phase_node = 3'd1;
  localparam [2:0] mem3_node = 3'd2;
  localparam [2:0] cache_fetch_node = 3'd3;
  localparam [2:0] cache_writeback_node = 3'd4;
    localparam [1:0] ahb_idle_node = 2'b00;
  localparam [1:0] ahb_busy_node = 2'b01;
  localparam [1:0] ahb_nonseq_node = 2'b10;
  localparam [1:0] ahb_seq_node = 2'b11;

  reg [2:0] curr_state_node /* synthesis PAP_MARK_DEBUG="true" */;
  reg [2:0] next_state_node;

  wire [ahbwlogbwpl_node-1:0] next_beat_count_node;
  wire final_beat_count_node;
  localparam [2:0] local_burst_type_node =
      (beat_count_threshold_node == 0)  ? 3'b000 :
      (beat_count_threshold_node == 3)  ? 3'b011 : 
      (beat_count_threshold_node == 7)  ? 3'b101 : 
      (beat_count_threshold_node == 15) ? 3'b111 : 
                                 3'b001;  
  wire beat_cnt_en_node;
  wire beat_cnt_reset_node;
  wire cache_access;
  wire bus_write_node;
  wire error_first_node;
  reg cancel_next_q_node;
  wire [1:0] normal_htrans_node;

  assign bus_error = hready & hresp &
                    ((curr_state_node == data_phase_node) | (curr_state_node == cache_fetch_node) |
                     (curr_state_node == cache_writeback_node));

  
  assign error_first_node = hresp & ~hready &
                      ((curr_state_node == data_phase_node) | (curr_state_node == cache_fetch_node) |
                       (curr_state_node == cache_writeback_node));
  // Update registered pipeline or controller state on the clock edge.
  // Register the controller state; reset and transition conditions determine each update.
  always @(posedge hclk)
    if (~hrese_tn)          cancel_next_q_node <= 1'b0;
    else if (error_first_node)   cancel_next_q_node <= 1'b1;
    else if (hready)       cancel_next_q_node <= 1'b0;

  assign bus_write_node = cache_bus_rw[0] & ~READ_ONLY_CACHE;

  // Register the controller state; reset and transition conditions determine each update.
  always @(posedge hclk)
    if (~hrese_tn | kill) curr_state_node <= adr_phase_node;
    else                  curr_state_node <= next_state_node;

  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @* begin
      if (bus_error) next_state_node = mem3_node;
      else case(curr_state_node)
        adr_phase_node: if (hready & |bus_rw)                               next_state_node = data_phase_node;             // exclusion-tag: ahb_cache_fsm HREADY0
                   else if (hready & bus_write_node & ~READ_ONLY_CACHE)     next_state_node = cache_writeback_node;        // exclusion-tag: ahb_cache_fsm HREADY1
                   else if (hready & cache_bus_rw[1])                   next_state_node = cache_fetch_node;            // exclusion-tag: ahb_cache_fsm HREADYread
                   else                                               next_state_node = adr_phase_node;
        data_phase_node:  if(hready)                                      next_state_node = mem3_node;
                     else                                            next_state_node = data_phase_node;
        mem3_node:        if(hold)                                        next_state_node = mem3_node;
                     else                                             next_state_node = adr_phase_node;
        cache_fetch_node: if(hready & final_beat_count_node & cache_bus_rw[0])      next_state_node = cache_writeback_node;  // exclusion-tag: ahb_cache_fsm FetchWriteback
                     else if(hready & final_beat_count_node & cache_bus_rw[1]) next_state_node = cache_fetch_node;      // exclusion-tag: ahb_cache_fsm FetchWait
                     else if(hready & final_beat_count_node & ~|cache_bus_rw)  next_state_node = adr_phase_node;
                     else                                             next_state_node = cache_fetch_node;
        cache_writeback_node:  if(hready & final_beat_count_node & cache_bus_rw[0]) next_state_node = cache_writeback_node; // exclusion-tag: ahb_cache_fsm WritebackWriteback
                     else if(hready & final_beat_count_node & cache_bus_rw[1]) next_state_node = cache_fetch_node;     // exclusion-tag: ahb_cache_fsm HREADY4
                     else if(hready & final_beat_count_node & ~|cache_bus_rw)  next_state_node = adr_phase_node;       // exclusion-tag: ahb_cache_fsm HREADY6
                     else                                             next_state_node = cache_writeback_node; // exclusion-tag: ahb_cache_fsm WritebackWriteback2
        default:                                                      next_state_node = adr_phase_node;
      endcase
  end

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(ahbwlogbwpl_node) beat_count_reg_u(hclk, ~hrese_tn | beat_cnt_reset_node, beat_cnt_en_node, next_beat_count_node, beat_count);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenr #(ahbwlogbwpl_node) beat_count_delayed_reg_u(hclk, ~hrese_tn | beat_cnt_reset_node, beat_cnt_en_node, beat_count, beat_count_delayed);
  assign next_beat_count_node = beat_count + 1'b1;

  assign final_beat_count_node = beat_count_delayed == beat_count_threshold_node[ahbwlogbwpl_node-1:0];
  assign beat_cnt_en_node = (((next_state_node == cache_writeback_node | next_state_node == cache_fetch_node) & hready & ~kill) |
                     (next_state_node == adr_phase_node & |cache_bus_rw & hready)) & ~kill;
  assign beat_cnt_reset_node = next_state_node == adr_phase_node;

  assign capture_en = ((curr_state_node == data_phase_node & bus_rw[1] & ~kill) |
                      (curr_state_node == cache_fetch_node & hready)) & ~bus_error;
  assign cache_fetch_capture_en = curr_state_node == cache_fetch_node & hready & ~kill & ~bus_error;
  assign cache_access = curr_state_node == cache_fetch_node | curr_state_node == cache_writeback_node;

  assign bus_hold = (curr_state_node == adr_phase_node & ((|bus_rw) | (|cache_bus_rw))) |
                    (curr_state_node == data_phase_node) |
                    (curr_state_node == cache_fetch_node & ~final_beat_count_node) |
                    (curr_state_node == cache_writeback_node & ~final_beat_count_node);

  assign bus_committed = (curr_state_node != adr_phase_node) & ~(READ_ONLY_CACHE & curr_state_node == mem3_node);

  
  assign normal_htrans_node =
                  (curr_state_node == adr_phase_node & hready & ((|bus_rw) | (|cache_bus_rw)) & ~kill) |
                  (cache_access & final_beat_count_node & |cache_bus_rw & hready & ~kill) ? ahb_nonseq_node : 
                  (cache_access & |beat_count) ? (BURST_EN ? ahb_seq_node : ahb_nonseq_node) : ahb_idle_node;
  assign htrans = cancel_next_q_node ? ahb_idle_node : normal_htrans_node;

  assign hwrite = ((bus_rw[0] | bus_write_node & ~kill) |
                  (curr_state_node == cache_writeback_node & |beat_count)) & ~READ_ONLY_CACHE;
  assign hburst = BURST_EN & ((|cache_bus_rw & ~kill) | (cache_access & |beat_count)) ? local_burst_type_node : 3'b0;

  
  // Qualify transfer completion with the bus handshake.
  assign cache_bus_ack = cache_access & hready & final_beat_count_node & ~bus_error;
  assign sel_bus_beat = (curr_state_node == adr_phase_node & (bus_rw[0] | bus_write_node)) |
                      (curr_state_node == data_phase_node & bus_rw[0]) |
                      (curr_state_node == cache_writeback_node) |
                      (curr_state_node == cache_fetch_node);

endmodule
