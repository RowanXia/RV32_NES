// Connects the RV32 fetch front end, integer pipeline, load/store path, and machine-mode control.
// Coordinates instruction flow, bus transactions, interrupts, and performance monitoring.


`include "config.vh"
`include "../perf/perf_defs.vh"

module RV32_core   (
   input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
   
   input wire m_timer_int,  // Machine timer interrupt request.
  input wire m_ext_int,  // Machine external interrupt request.
  input wire m_sw_int,  // Machine software interrupt request.
   input wire [63:0] mtime_clint,  // 64-bit machine timer value from the local interrupt timer.
   
   input wire [31:0] hrdata,  // AHB read-data bus returned by the selected target.
   input wire hready,  // AHB transfer-completion handshake from the selected slave.
  input wire hresp,  // AHB response status returned by the selected slave.
   output wire hclk,  // Clock forwarded to the AHB interface.
  output wire hrese_tn,  // Active-low AHB reset generated from the core reset.
   output wire [31:0] haddr,  // AHB byte address of the active bus transfer.
   output wire [31:0] hwdata,  // AHB write-data bus.
   output wire [3:0] hwstrb,  // Byte-lane strobes for the AHB write transaction.
   output wire hwrite,  // Indicates an AHB write transfer.
   output wire [2:0] hsize,  // AHB transfer size encoding.
   output wire [2:0] hburst,  // AHB burst-type encoding.
   output wire [3:0] hprot,  // AHB protection attributes.
   output wire [1:0] htrans,  // AHB transfer type for the selected bus request.
   output wire hmastlock,  // AHB locked-sequence indicator.
   input wire external_hold,  // External backpressure request that suspends pipeline progression.
   input wire perf_window_marker,  // Performance event or counter control.
   output wire perf_window_active,  // Performance event or counter control.
   output wire [(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH)-1:0] perf_snapshot_counters,  // Performance event or counter control.
   output wire [`PERF_COUNTER_COUNT-1:0] perf_snapshot_overflow,  // Performance event or counter control.
   output wire [31:0] perf_snapshot_id,  // Performance event or counter control.
   output wire perf_snapshot_valid,  // Performance event or counter control.
   output wire perf_snapshot_done  // Performance event or counter control.
);

  wire hold_f /* synthesis PAP_MARK_DEBUG="true" */;
  wire hold_d /* synthesis PAP_MARK_DEBUG="true" */;
  wire hold_e /* synthesis PAP_MARK_DEBUG="true" */;
  wire hold_m /* synthesis PAP_MARK_DEBUG="true" */;
  wire hold_w /* synthesis PAP_MARK_DEBUG="true" */;
  wire kill_d /* synthesis PAP_MARK_DEBUG="true" */;
  wire kill_e /* synthesis PAP_MARK_DEBUG="true" */;
  wire kill_m /* synthesis PAP_MARK_DEBUG="true" */;
  wire kill_w /* synthesis PAP_MARK_DEBUG="true" */;
  wire trap_m /* synthesis PAP_MARK_DEBUG="true" */;
  wire ret_m;

  
  wire int_div_e;
  wire csr_read_m;
  wire csr_write_m;
  wire privileged_m;
  wire [31:0] forwarded_src_ae;
  wire [31:0] forwarded_src_be;
  wire [31:0] csr_source_operand_m;
  wire [2:0] funct3_e;
  wire [31:0] instr_d /* synthesis PAP_MARK_DEBUG="true" */;
  wire [31:0] instr_m /* synthesis PAP_MARK_DEBUG="true" */;
  wire [31:0] original_instr_m;
  // Fetch PC after the instruction alignment/spill selection.
  wire [31:0] pc_spill_f /* synthesis PAP_MARK_DEBUG="true" */;
  // Program counter associated with the execute-stage instruction.
  wire [31:0] pce /* synthesis PAP_MARK_DEBUG="true" */;
  wire [31:0] link_address_e;
  // Program counter associated with the memory-stage instruction.
  wire [31:0] pcm /* synthesis PAP_MARK_DEBUG="true" */;
  // Memory-stage PC after the instruction spill-address selection.
  wire [31:0] pc_spill_m /* synthesis PAP_MARK_DEBUG="true" */;
  wire [31:0] csr_read_val_w;
  wire [31:0] mul_div_result_w;
  wire [31:0] epcm;
  wire [31:0] trap_vector_m;
  wire [1:0] memory_operation_e;
  wire [1:0] memory_operation_m /* synthesis PAP_MARK_DEBUG="true" */;
  wire instr_valid_d /* synthesis PAP_MARK_DEBUG="true" */;
  wire instr_valid_e /* synthesis PAP_MARK_DEBUG="true" */;
  wire instr_valid_m /* synthesis PAP_MARK_DEBUG="true" */;
  wire instr_misaligned_fault_m;
  wire illegal_base_instr_d;
  wire illegal_instr_d;
  wire load_misaligned_fault_m;
  wire load_access_fault_m;
  wire store_amo_misaligned_fault_m;
  wire store_amo_access_fault_m;
  wire invalidate_i_cache_m;
  wire kill_d_cache_m;
  wire pc_src_e /* synthesis PAP_MARK_DEBUG="true" */;
  wire csr_write_fence_m;
  wire div_busy_e;
  // Combined structural or operand dependency Hold request.
  wire structural_hold_d /* synthesis PAP_MARK_DEBUG="true" */;
  // Decode-stage load-use dependency requiring a Hold.
  wire load_hold_d /* synthesis PAP_MARK_DEBUG="true" */;
  wire store_hold_d /* synthesis PAP_MARK_DEBUG="true" */;
  wire mul_div_active_e;                      

  wire [4:0] rd_e;
  wire [4:0] rd_m;
  wire [4:0] rd_w;

  
  wire fetch_hold_f;
  wire memory_hold_m;

  
  wire [2:0] funct3_m;
  wire [31:0] effective_address_e;
  wire [31:0] resolved_control_flow_address_e;
  wire [31:0] store_data_m;
  wire [31:0] effective_address_m;
  wire [31:0] fault_address_m;
  wire [31:0] load_data_w;
  wire committed_m;

  
  wire [31:0] fetch_haddr;
  wire [2:0] fetch_hburst;
  wire [1:0] fetch_htrans;
  wire [2:0] fetch_hsize;
  wire fetch_hwrite;
  wire fetch_hready;

  
  wire [31:0] memory_haddr;
  wire [31:0] memory_hwdata;
  wire [3:0] memory_hwstrb;
  wire memory_hwrite;
  wire memory_hready;

  wire prediction_wrong_e /* synthesis PAP_MARK_DEBUG="true" */;
  wire prediction_wrong_m /* synthesis PAP_MARK_DEBUG="true" */;
  wire direction_prediction_wrong_m;
  wire target_prediction_wrong_m;
  wire return_prediction_wrong_m;
  wire instruction_class_wrong_m;
  wire [3:0] instruction_class_m /* synthesis PAP_MARK_DEBUG="true" */;
  wire instr_access_fault_f;
  wire fetch_hresp;
  wire memory_hresp;
  wire [2:0] memory_hsize;
  wire [2:0] memory_hburst;
  wire [1:0] memory_htrans;

  wire d_cache_miss;
  wire d_cache_access;
  wire i_cache_miss;
  wire i_cache_access;
  wire committed_f;
  wire branch_d;
  wire branch_e;
  wire jump_d;
  wire jump_e;
  wire d_cache_hold_m;
  wire i_cache_hold_f;
  wire wait_m;                           
  wire perf_i_cache_request_accept /* synthesis PAP_MARK_DEBUG="true" */;
  wire perf_i_cache_miss_start /* synthesis PAP_MARK_DEBUG="true" */;
  wire perf_d_cache_load_accept /* synthesis PAP_MARK_DEBUG="true" */;
  wire perf_d_cache_load_miss_start /* synthesis PAP_MARK_DEBUG="true" */;
  wire perf_d_cache_store_accept;
  wire perf_d_cache_store_miss_start;
  wire perf_d_cache_writeback_start /* synthesis PAP_MARK_DEBUG="true" */;
  wire perf_ahb_wait;

  
  wire [(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH)-1:0] perf_live_counters;

  
  // Fetch instructions and track predicted control flow.
  // Grouped pipeline and cache observations for capture tools.
`ifdef CFG_ILA_PROBES
  // Observation-only probe bundle for internal debug and waveform capture.
  wire [30:0] ila_pc_e_31_1 /* synthesis PAP_MARK_DEBUG="true" */;
  // Observation-only probe bundle for internal debug and waveform capture.
  wire [30:0] ila_pc_m_31_1 /* synthesis PAP_MARK_DEBUG="true" */;
  // Observation-only probe bundle for internal debug and waveform capture.
  wire [31:0] ila_instr_m /* synthesis PAP_MARK_DEBUG="true" */;
  // Observation-only probe bundle for internal debug and waveform capture.
  wire [30:0] ila_pipe_status /* synthesis PAP_MARK_DEBUG="true" */;
  // Observation-only probe bundle for internal debug and waveform capture.
  wire [6:0] ila_cache_events /* synthesis PAP_MARK_DEBUG="true" */;

  assign ila_pc_e_31_1 = pce[31:1];
  assign ila_pc_m_31_1 = pc_spill_m[31:1];
  assign ila_instr_m = instr_m;

  // Debug-only bundle: exposes selected pipeline status without changing its control path.
  assign ila_pipe_status[0]  = reset;
  assign ila_pipe_status[1]  = perf_window_marker;
  assign ila_pipe_status[2]  = perf_window_active;
  assign ila_pipe_status[3]  = instr_valid_d;
  assign ila_pipe_status[4]  = instr_valid_e;
  assign ila_pipe_status[5]  = instr_valid_m;
  assign ila_pipe_status[6]  = hold_f;
  assign ila_pipe_status[7]  = hold_d;
  assign ila_pipe_status[8]  = hold_e;
  assign ila_pipe_status[9]  = hold_m;
  assign ila_pipe_status[10] = hold_w;
  assign ila_pipe_status[11] = kill_d;
  assign ila_pipe_status[12] = kill_e;
  assign ila_pipe_status[13] = kill_m;
  assign ila_pipe_status[14] = kill_w;
  assign ila_pipe_status[15] = instr_valid_m & ~hold_w & ~kill_w;
  assign ila_pipe_status[16] = load_hold_d;
  assign ila_pipe_status[17] = store_hold_d;
  assign ila_pipe_status[18] = structural_hold_d;
  assign ila_pipe_status[19] = div_busy_e;
  assign ila_pipe_status[20] = prediction_wrong_e;
  assign ila_pipe_status[21] = prediction_wrong_m;
  assign ila_pipe_status[22] = branch_e;
  assign ila_pipe_status[23] = pc_src_e;
  assign ila_pipe_status[24] = hready;
  assign ila_pipe_status[25] = hresp;
  assign ila_pipe_status[26] = fetch_hold_f;
  assign ila_pipe_status[27] = memory_hold_m;
  assign ila_pipe_status[28] = i_cache_hold_f;
  assign ila_pipe_status[29] = d_cache_hold_m;
  assign ila_pipe_status[30] = external_hold;

  assign ila_cache_events[0] = perf_i_cache_request_accept;
  assign ila_cache_events[1] = perf_i_cache_miss_start;
  assign ila_cache_events[2] = i_cache_miss;
  assign ila_cache_events[3] = perf_d_cache_load_accept;
  assign ila_cache_events[4] = perf_d_cache_load_miss_start;
  assign ila_cache_events[5] = d_cache_miss;
  assign ila_cache_events[6] = perf_d_cache_writeback_start;
`endif


  // Fetch front end: supplies instructions, predicted flow, and synchronized PC values.
  // Maintain fetch PCs, align instruction words, and transport instructions between stages.
  fetch_frontend  fetch_frontend_i_u(.clk(clk), .reset(reset),
    .hold_f(hold_f), .hold_d(hold_d), .hold_e(hold_e), .hold_m(hold_m), .hold_w(hold_w), .kill_d(kill_d), .kill_e(kill_e), .kill_m(kill_m), .kill_w(kill_w),
    .instr_valid_e(instr_valid_e), .instr_valid_d(instr_valid_d),
    .branch_d(branch_d), .branch_e(branch_e), .jump_d(jump_d), .jump_e(jump_e), .i_cache_hold_f(i_cache_hold_f),
    
    .hrdata(hrdata), .pc_spill_f(pc_spill_f), .fetch_haddr(fetch_haddr),
    .fetch_hold_f(fetch_hold_f), .fetch_hburst(fetch_hburst), .fetch_htrans(fetch_htrans), .fetch_hsize(fetch_hsize), .fetch_hready(fetch_hready), .fetch_hresp(fetch_hresp), .fetch_hwrite(fetch_hwrite),
    .i_cache_access(i_cache_access), .i_cache_miss(i_cache_miss),
    .perf_i_cache_request_accept(perf_i_cache_request_accept),
    .perf_i_cache_miss_start(perf_i_cache_miss_start),
    
    .link_address_e(link_address_e), .pc_src_e(pc_src_e), .resolved_control_flow_address_e(resolved_control_flow_address_e), .effective_address_m(effective_address_m), .pce(pce), .prediction_wrong_e(prediction_wrong_e),  .prediction_wrong_m(prediction_wrong_m),
    
    .committed_f(committed_f), .epcm(epcm), .trap_vector_m(trap_vector_m), .ret_m(ret_m), .trap_m(trap_m), .invalidate_i_cache_m(invalidate_i_cache_m), .csr_write_fence_m(csr_write_fence_m),
    .instr_d(instr_d), .instr_m(instr_m), .original_instr_m(original_instr_m), .pcm(pcm), .pc_spill_m(pc_spill_m), .instruction_class_m(instruction_class_m), .direction_prediction_wrong_m(direction_prediction_wrong_m),
    .target_prediction_wrong_m(target_prediction_wrong_m), .return_prediction_wrong_m(return_prediction_wrong_m), .instruction_class_wrong_m(instruction_class_wrong_m),
    
    .illegal_base_instr_d(illegal_base_instr_d), .illegal_instr_d(illegal_instr_d), .instr_misaligned_fault_m(instr_misaligned_fault_m),
    .instr_access_fault_f(instr_access_fault_f));

  
  // Execute decoded integer instructions and generate writeback results.
  // Integer pipeline: carries decode controls, arithmetic operands, and writeback results.
  // Connect decode, integer execution, multiply/divide, and writeback datapaths.
  integer_pipeline  integer_pipeline_i_u(.clk(clk), .reset(reset),
     
     .instr_d(instr_d), .illegal_instr_d(illegal_instr_d), .illegal_base_instr_d(illegal_base_instr_d),
     
     .pce(pce), .link_address_e(link_address_e), .effective_address_e(effective_address_e), .resolved_control_flow_address_e(resolved_control_flow_address_e), .int_div_e(int_div_e),
     .funct3_e(funct3_e), .forwarded_src_ae(forwarded_src_ae), .forwarded_src_be(forwarded_src_be), .mul_div_active_e(mul_div_active_e),
     
     .memory_operation_e(memory_operation_e),     
     .memory_operation_m(memory_operation_m),     
     .store_data_m(store_data_m), 
     .funct3_m(funct3_m),    
     .csr_source_operand_m(csr_source_operand_m),
     .rd_e(rd_e), .rd_m(rd_m), .kill_d_cache_m(kill_d_cache_m),
     .branch_d(branch_d), .branch_e(branch_e), .jump_d(jump_d), .jump_e(jump_e),
     
     .csr_read_val_w(csr_read_val_w), .mul_div_result_w(mul_div_result_w), .rd_w(rd_w), .load_data_w(load_data_w[31:0]),
     .instr_valid_m(instr_valid_m), .instr_valid_e(instr_valid_e), .instr_valid_d(instr_valid_d),
     
     .hold_d(hold_d), .hold_e(hold_e), .hold_m(hold_m), .hold_w(hold_w), .kill_d(kill_d), .kill_e(kill_e), .kill_m(kill_m), .kill_w(kill_w),
     .structural_hold_d(structural_hold_d), .load_hold_d(load_hold_d), .store_hold_d(store_hold_d), .pc_src_e(pc_src_e),
     .csr_read_m(csr_read_m), .csr_write_m(csr_write_m), .privileged_m(privileged_m), .csr_write_fence_m(csr_write_fence_m), .invalidate_i_cache_m(invalidate_i_cache_m));

  // Handle memory operations and the data-cache interface.
  // Load/store interface: handles effective addresses, cached accesses, and faults.
  // Translate pipeline memory operations into load/store and cache requests.
  load_store_unit  load_store_unit_i_u(
    .clk(clk), .reset(reset), .hold_m(hold_m), .kill_m(kill_m), .hold_w(hold_w), .kill_w(kill_w),
    
    .memory_operation_m(memory_operation_m), .funct3_m(funct3_m),
    .committed_m(committed_m), .d_cache_miss(d_cache_miss), .d_cache_access(d_cache_access),
    .perf_d_cache_load_accept(perf_d_cache_load_accept),
    .perf_d_cache_load_miss_start(perf_d_cache_load_miss_start),
    .perf_d_cache_store_accept(perf_d_cache_store_accept),
    .perf_d_cache_store_miss_start(perf_d_cache_store_miss_start),
    .perf_d_cache_writeback_start(perf_d_cache_writeback_start),
    .effective_address_e(effective_address_e), .effective_address_m(effective_address_m), .store_data_m(store_data_m),
    .load_data_w(load_data_w), .kill_d_cache_m(kill_d_cache_m),
    
    .memory_haddr(memory_haddr),  .hrdata(hrdata), .memory_hwdata(memory_hwdata), .memory_hwstrb(memory_hwstrb), .memory_hsize(memory_hsize),
    .memory_hburst(memory_hburst), .memory_htrans(memory_htrans), .memory_hwrite(memory_hwrite), .memory_hready(memory_hready), .memory_hresp(memory_hresp),
    .d_cache_hold_m(d_cache_hold_m),                
    .fault_address_m(fault_address_m),                
    .load_misaligned_fault_m(load_misaligned_fault_m),        
    .load_access_fault_m(load_access_fault_m),            
    .store_amo_misaligned_fault_m(store_amo_misaligned_fault_m),    
    .store_amo_access_fault_m(store_amo_access_fault_m),        
    .memory_hold_m(memory_hold_m));

  if (1) begin : ahb_bus_gen
    // Arbitrate instruction and data requests onto the shared AHB master interface.
    ahb_bus_unit  ahb_bus_unit_i_u(
      .clk(clk), .reset(reset),
      
      .fetch_haddr(fetch_haddr), .fetch_hburst(fetch_hburst), .fetch_htrans(fetch_htrans), .fetch_hready(fetch_hready), .fetch_hresp(fetch_hresp), .fetch_hsize(fetch_hsize),
      
      .memory_haddr(memory_haddr), .memory_hwdata(memory_hwdata), .memory_hwstrb(memory_hwstrb), .memory_hsize(memory_hsize), .memory_hburst(memory_hburst),
      .memory_htrans(memory_htrans), .memory_hwrite(memory_hwrite), .memory_hready(memory_hready), .memory_hresp(memory_hresp),
      
      .hready(hready), .hresp(hresp), .hclk(hclk), .hrese_tn(hrese_tn),
      .haddr(haddr), .hwdata(hwdata), .hwstrb(hwstrb), .hwrite(hwrite), .hsize(hsize), .hburst(hburst),
      .hprot(hprot), .htrans(htrans), .hmastlock(hmastlock));
  end

  
  // Resolve pipeline holds, kills, and redirect priorities.
  // Hazard controller: combines stage backpressure and instruction cancellation.
  // Generate pipeline Hold and Kill controls from dependencies and redirects.
  pipeline_hazard_control pipeline_hazard_control_i_u(
    .prediction_wrong_e(prediction_wrong_e), .csr_write_fence_m(csr_write_fence_m), .ret_m(ret_m), .trap_m(trap_m),
    .structural_hold_d(structural_hold_d),
    .memory_hold_m(memory_hold_m), .fetch_hold_f(fetch_hold_f),
    .external_hold(external_hold),
    .div_busy_e(div_busy_e),
    .wait_m(wait_m),
    
    .hold_f(hold_f), .hold_d(hold_d), .hold_e(hold_e), .hold_m(hold_m), .hold_w(hold_w),
    .kill_d(kill_d), .kill_e(kill_e), .kill_m(kill_m), .kill_w(kill_w));

  // Select this hardware path from the active configuration.
  if (`CFG_PERF_ENABLE) begin : performance_monitor_gen
    assign perf_ahb_wait = htrans[1] & ~hready;
  // Performance monitor: observes qualified pipeline and cache events.
    // Accumulate CoreMark performance events and provide frozen snapshots.
    perf_monitor_top perf_monitor_top_i_u(
      .clk(clk), .reset(reset), .window_marker(perf_window_marker),
      .instr_valid_m(instr_valid_m), .hold_w(hold_w), .kill_w(kill_w),
      .instruction_class_m(instruction_class_m), .prediction_wrong_m(prediction_wrong_m),
      .i_cache_miss(i_cache_miss), .d_cache_miss(d_cache_miss),
      .i_cache_access(i_cache_access), .d_cache_access(d_cache_access),
      .hold_f(hold_f), .fetch_hold_f(fetch_hold_f), .i_cache_hold_f(i_cache_hold_f),
      .memory_hold_m(memory_hold_m), .d_cache_hold_m(d_cache_hold_m),
      .div_busy_e(div_busy_e), .structural_hold_d(structural_hold_d),
      .perf_i_cache_request_accept(perf_i_cache_request_accept),
      .perf_i_cache_miss_start(perf_i_cache_miss_start),
      .perf_d_cache_load_accept(perf_d_cache_load_accept),
      .perf_d_cache_load_miss_start(perf_d_cache_load_miss_start),
      .perf_d_cache_store_accept(perf_d_cache_store_accept),
      .perf_d_cache_store_miss_start(perf_d_cache_store_miss_start),
      .perf_d_cache_writeback_start(perf_d_cache_writeback_start),
      .ahb_wait(perf_ahb_wait), .external_hold(external_hold), .wait_m(wait_m),
      .window_active(perf_window_active), .live_counter_values(perf_live_counters),
      .snapshot_values(perf_snapshot_counters), .snapshot_overflow(perf_snapshot_overflow),
      .snapshot_id(perf_snapshot_id), .snapshot_valid(perf_snapshot_valid),
      .snapshot_done(perf_snapshot_done));
  end else begin : performance_monitor_gen
    assign perf_ahb_wait = 1'b0;
    assign perf_window_active = 1'b0;
    assign perf_live_counters = {(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH){1'b0}};
    assign perf_snapshot_counters = {(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH){1'b0}};
    assign perf_snapshot_overflow = {`PERF_COUNTER_COUNT{1'b0}};
    assign perf_snapshot_id = 32'b0;
    assign perf_snapshot_valid = 1'b0;
    assign perf_snapshot_done = 1'b0;
  end

  
  if (1) begin : privilege_gen
    // Handle CSRs, interrupts, and trap redirection.
    // Coordinate privileged instruction handling, CSR state, and trap control.
    privilege_unit  privilege_unit_i_u(
      .clk(clk), .reset(reset),
      .kill_d(kill_d), .kill_e(kill_e), .kill_m(kill_m), .kill_w(kill_w), .hold_d(hold_d), .hold_e(hold_e), .hold_m(hold_m), .hold_w(hold_w),
      .csr_read_m(csr_read_m), .csr_write_m(csr_write_m), .csr_source_operand_m(csr_source_operand_m), .pcm(pcm), .pc_spill_m(pc_spill_m),
      .instr_m(instr_m), .original_instr_m(original_instr_m), .csr_read_val_w(csr_read_val_w), .epcm(epcm), .trap_vector_m(trap_vector_m),
      .ret_m(ret_m), .trap_m(trap_m), .invalidate_i_cache_m(invalidate_i_cache_m), .d_cache_hold_m(d_cache_hold_m), .i_cache_hold_f(i_cache_hold_f),
      .instr_valid_m(instr_valid_m), .committed_m(committed_m), .committed_f(committed_f),
      .load_hold_d(load_hold_d), .store_hold_d(store_hold_d),
      .direction_prediction_wrong_m(direction_prediction_wrong_m), .target_prediction_wrong_m(target_prediction_wrong_m), .prediction_wrong_m(prediction_wrong_m),
      .return_prediction_wrong_m(return_prediction_wrong_m), .instruction_class_wrong_m(instruction_class_wrong_m), .div_busy_e(div_busy_e),
      .instruction_class_m(instruction_class_m), .d_cache_miss(d_cache_miss), .d_cache_access(d_cache_access), .i_cache_miss(i_cache_miss), .i_cache_access(i_cache_access), .privileged_m(privileged_m),
      .instr_misaligned_fault_m(instr_misaligned_fault_m), .illegal_instr_d(illegal_instr_d),
      .load_misaligned_fault_m(load_misaligned_fault_m), .store_amo_misaligned_fault_m(store_amo_misaligned_fault_m),
      .m_timer_int(m_timer_int), .m_ext_int(m_ext_int), .m_sw_int(m_sw_int),
      .mtime_clint(mtime_clint), .fault_address_m(fault_address_m),
      .instr_access_fault_f(instr_access_fault_f), .load_access_fault_m(load_access_fault_m), .store_amo_access_fault_m(store_amo_access_fault_m),
      .wait_m(wait_m));
  end

  
  // Select this hardware path from the active configuration.
  if (`CFG_M_SUPPORTED | `CFG_ZMMUL_SUPPORTED) begin : muldiv_gen
    // Select multiplication and iterative division results for the integer execution path.
    muldiv_unit  muldiv_unit_i_u(.clk(clk), .reset(reset), .hold_m(hold_m), .hold_w(hold_w), .kill_e(kill_e), .kill_m(kill_m), .kill_w(kill_w),
      .forwarded_src_ae(forwarded_src_ae), .forwarded_src_be(forwarded_src_be),
      .funct3_e(funct3_e), .funct3_m(funct3_m), .int_div_e(int_div_e), .mul_div_active_e(mul_div_active_e),
      .mul_div_result_w(mul_div_result_w), .div_busy_e(div_busy_e));
  end else begin : muldiv_gen
    assign mul_div_result_w = 1'b0;
    assign div_busy_e = 1'b0;
  end

endmodule
