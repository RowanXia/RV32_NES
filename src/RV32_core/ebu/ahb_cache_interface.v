// Adapts cache-line requests and responses to the AHB transfer protocol.
// Exchanges refill data, writeback data, and bus-ready status with the cache.


`include "config.vh"

module ahb_cache_interface  #(
  parameter beatsperline_node = 4,  
  parameter ahbwlogbwpl_node = 2,   
  parameter linelen_node = 128,       
  parameter READ_ONLY_CACHE = 0
)(
  input wire hclk,  // Clock forwarded to the AHB interface.
  input wire hrese_tn,  // Active-low AHB reset generated from the core reset.
  
  input wire hready,  // AHB transfer-completion handshake from the selected slave.
  input wire hresp,  // AHB response status returned by the selected slave.
  output wire [1:0] htrans,  // AHB transfer type for the selected bus request.
  output wire hwrite,  // Indicates an AHB write transfer.
  output wire [2:0] hsize,  // AHB transfer size encoding.
  output wire [2:0] hburst,  // AHB burst-type encoding.
  
  input wire [31:0] hrdata,  // AHB read-data bus returned by the selected target.
  output wire [31:0] haddr,  // AHB byte address of the active bus transfer.
  output wire [31:0] hwdata,  // AHB write-data bus.
  output wire [3:0] hwstrb,  // Byte-lane strobes for the AHB write transaction.

  
  input wire [31:0] cache_bus_adr,  // External memory transaction associated with cache control.
  input wire [31:0] cache_read_data_word_m,  // Cache-side data, address, or operation control.
  input wire cacheable_or_kill_cache_m,  // Cache-side data, address, or operation control.
  input wire cacheable,  // Cache-side data, address, or operation control.
  input wire [1:0] cache_bus_rw,  // External memory transaction associated with cache control.
  output wire cache_bus_ack,  // External memory transaction associated with cache control.
  output wire [linelen_node-1:0] fetch_buffer,  // Instruction-fetch request, response, or control.
  output wire [ahbwlogbwpl_node-1:0] beat_count,  // Provides beat count for this module.
  output wire sel_bus_beat,  // Provides sel bus beat for this module.
  output wire writeback_prefetch_en,  // Instruction-fetch request, response, or control.
  output wire refill_write_en,  // Enables writing the fetched line into the cache.
  output wire [ahbwlogbwpl_node-1:0] refill_beat,  // Provides refill beat for this module.
  output wire [31:0] refill_data,  // Data supplied from a cache-line refill transaction.

  
  input wire [31:0] p_adr,  // Set index used for replacement metadata updates.
  input wire [31:0] store_data_m,  // Store data used by the memory-stage datapath or control.
  input wire [1:0] bus_rw,  // Provides bus rw for this module.
  input wire [2:0] size,  // Transfer size encoding used for byte-lane or access checks.

  
  input wire hold,  // Prevents the corresponding pipeline stage from advancing.
  input wire kill,  // Cancels invalid or wrong-path pipeline work.
  output wire bus_hold,  // Prevents the corresponding pipeline stage from advancing.
  output wire bus_committed,  // Provides bus committed for this module.
  output wire bus_error);  // Provides bus error for this module.


  localparam                  beat_count_threshold_node = beatsperline_node - 1;  
  wire [31:0] local_haddr_node;                             
  wire [ahbwlogbwpl_node-1:0] beat_count_delayed;                       
  wire capture_en;                              
  wire cache_fetch_capture_en;
 wire [31:0] pre_hwdata_node;                              

  genvar                      index;

  
  // Apply the same combinational operation to each configured element.
  for (index = 0; index < beatsperline_node; index = index + 1) begin : fetchbufferbeat
    wire [beatsperline_node-1:0] capture_beat_node;
    assign capture_beat_node[index] = capture_en & (index == beat_count_delayed);
    // Register stage data under the supplied clock, reset, and enable controls.
    ffen #(32) refill_beat_ff_u(.clk(hclk), .en(capture_beat_node[index]), .d(hrdata),
      .q(fetch_buffer[(index+1)*(32'd32)-1:index*(32'd32)]));
  end

  // Select the appropriate datapath value from the available inputs.
  mux2 #(32) localadrmux_u(p_adr, cache_bus_adr, cacheable, local_haddr_node);
  // Select the address associated with the active request.
  assign haddr = ({{(32'd32)-ahbwlogbwpl_node{1'b0}}, beat_count} << 2) + local_haddr_node;

  // Select the appropriate datapath value from the available inputs.
  mux2 #(3) sizemux_u(.d0(size), .d1(3'b010), .s(cacheable), .generic_result(hsize));

  
  wire [31:0] cache_read_data_word_ahb_node;
  assign cache_read_data_word_ahb_node = cache_read_data_word_m;

  // Select the appropriate datapath value from the available inputs.
  mux2 #(32) hwdata_mux_u(.d0(cache_read_data_word_ahb_node), .d1(store_data_m[31:0]),
    .s(~(cacheable_or_kill_cache_m)), .generic_result(pre_hwdata_node));
  // Register stage data under the supplied clock, reset, and enable controls.
  ffen #(32) wdreg_u(hclk, hready, pre_hwdata_node, hwdata); 

  if (READ_ONLY_CACHE) begin
    assign hwstrb = 1'b0;
  end else begin 
    wire [3:0] bus_byte_mask_m_node;                           

    // Produce byte-lane write enables from transfer size and address.
    store_byte_mask #(32) busswbytemask_u(.size(hsize), .adr(haddr[1:0]), .byte_mask(bus_byte_mask_m_node), .byte_mask_extended());
    // Register stage data under the supplied clock, reset, and enable controls.
    ffen #(4) hwstrb_reg_u(hclk, hready, bus_byte_mask_m_node[3:0], hwstrb);
  end

  // Sequence address, refill, and writeback transactions on the AHB cache interface.
  ahb_cache_fsm #(beat_count_threshold_node, ahbwlogbwpl_node, READ_ONLY_CACHE, `CFG_BURST_EN) ahb_cache_fsm_i_u(
    .hclk(hclk), .hrese_tn(hrese_tn), .kill(kill), .bus_rw(bus_rw), .hold(hold), .bus_committed(bus_committed), .bus_hold(bus_hold), .capture_en(capture_en), .cache_fetch_capture_en(cache_fetch_capture_en), .sel_bus_beat(sel_bus_beat),
    .cache_bus_rw(cache_bus_rw), .cache_bus_ack(cache_bus_ack), .beat_count(beat_count), .beat_count_delayed(beat_count_delayed),
    .hready(hready), .hresp(hresp), .bus_error(bus_error), .htrans(htrans), .hwrite(hwrite), .hburst(hburst));

  assign refill_write_en = cache_fetch_capture_en;
  assign refill_beat = beat_count_delayed;
  assign refill_data = hrdata;
  // Qualify transfer completion with the bus handshake.
  assign writeback_prefetch_en = hready & ~hresp & htrans[1] & hwrite;
endmodule
