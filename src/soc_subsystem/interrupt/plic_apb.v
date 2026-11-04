// Module role: Arbitrates external interrupt sources for the machine-mode context.
// Behavioral interface: Priority, enable, pending, threshold, claim and completion are software-visible via APB.

`include "../config.vh"
`define C 1

module plic_apb    (
  input wire pclk_link,
  input wire prese_tn_link,
  input wire psel_link,
  input wire [27:0] paddr_link,
  input wire [31:0] pwdata_link,
  input wire [3:0] pstrb_link,
  input wire pwrite_link,
  input wire penable_link,
  output wire [31:0] prdata_link,
  output wire pready_link,
  input wire uart_intr_link,
  input wire gpio_intr_link,
  output wire m_ext_int_link
);

  wire [5:0] priority_entry_index_node;
  wire [5:0] complete_id_node;

  // APB register offsets for the single machine-mode interrupt context
  localparam plic_intpriority0_node   = 24'h000000;
  localparam plic_intpending0_node    = 24'h001000;
  localparam plic_intpending1_node    = 24'h001004;
  localparam plic_inten00_node        = 24'h002000;
  localparam plic_inten01_node        = 24'h002004;
  localparam plic_threshold0_node     = 24'h200000;
  localparam plic_claimcomplete0_node = 24'h200004;

  wire memwrite_node;
  wire memread_node;
  wire [23:0] entry_node;
  wire [31:0] uart_write_data_link;
  reg [31:0] uart_read_data_link;

  // Source-facing pending, priority and in-service bookkeeping
  wire [`CFG_PLIC_NUM_SRC:1] requests_node;
  reg [(`CFG_PLIC_NUM_SRC*3)-1:0] int_priority_node;
  reg [`CFG_PLIC_NUM_SRC:1] int_in_progress_node;
  wire [`CFG_PLIC_NUM_SRC:1] int_pending_node;
  wire [`CFG_PLIC_NUM_SRC:1] next_int_pending_node;

  // context-dependent signals
  reg [(`C*3)-1:0] int_threshold_node;
  reg [(`C*`CFG_PLIC_NUM_SRC)-1:0] int_en_node;
  reg [(`C*6)-1:0] int_claim_node; // ID's are 6 bits if we stay within 63 sources
  wire [(`C*7*`CFG_PLIC_NUM_SRC)-1:0] irq_matrix_node;
  wire [(`C*7)-1:0] priorities_with_irqs_node;
  wire [(`C*7)-1:0] max_priority_with_irqs_node;
  wire [(`C*`CFG_PLIC_NUM_SRC)-1:0] irqs_at_max_priority_node;
  reg [(`C*7)-1:0] thresh_mask_node;
  wire [`CFG_PLIC_NUM_SRC-1:0] one_node;

  // Guard part selects when the implemented source count is below one 32-bit register.
  // These bounds avoid invalid slices in otherwise inactive configurations.
  // The current design implements 14 source slots.

  localparam plic_src_top_node = (`CFG_PLIC_NUM_SRC >= 32) ? `CFG_PLIC_NUM_SRC : 1;
  localparam plic_src_bot_node = (`CFG_PLIC_NUM_SRC >= 32) ? 32 : 1;
  localparam plic_src_dintop_node = (`CFG_PLIC_NUM_SRC >= 32) ? `CFG_PLIC_NUM_SRC -32 : 0;
  localparam plic_src_ext_node = (`CFG_PLIC_NUM_SRC >= 32) ? 63-`CFG_PLIC_NUM_SRC : 31;

  // =======
  // APB access decoding (register view)
  // =======

  assign priority_entry_index_node = entry_node[7:2];
  assign complete_id_node = uart_write_data_link[5:0];
  assign memwrite_node = pwrite_link & penable_link & psel_link;  // APB writes take effect in the access phase
  assign memread_node  = ~pwrite_link & psel_link & ~penable_link; // Sample the APB read in setup to avoid duplicate side effects
  assign pready_link   = 1'b1;                     // This PLIC does not insert APB wait states
  assign entry_node    = {paddr_link[23:2],2'b0};
  assign one_node[`CFG_PLIC_NUM_SRC-1:1] = 1'b0; assign one_node[0] = 1'b1; // Vivado does not like this as a single assignment.

  // The register interface uses full 32-bit software accesses.
  // -- Note PLIC registers are 32 bits no matter what; access them with LW SW.
  assign uart_write_data_link = pwdata_link[31:0];
  assign prdata_link = uart_read_data_link;

  // ==================
  // Register read/write behavior and claim-complete side effects
  // ==================
  localparam plic_num_src_min_32_node = `CFG_PLIC_NUM_SRC < 32 ? `CFG_PLIC_NUM_SRC : 31;

  always @(posedge pclk_link) begin
    // resetting
    if (~prese_tn_link) begin
      int_priority_node   <= 1'b0;
      int_en_node         <= 1'b0;
      int_threshold_node  <= 1'b0;
      int_in_progress_node <= 1'b0;
    // writing
    end else begin
      if (memwrite_node)
        casez(entry_node)
          24'h0000??:
            if ((priority_entry_index_node != 0) & (priority_entry_index_node <= `CFG_PLIC_NUM_SRC))
              int_priority_node[((priority_entry_index_node-1))*3 +:3] <= uart_write_data_link[2:0];
          plic_inten00_node:        int_en_node[0 +: ((plic_num_src_min_32_node)-(1)+1)] <= uart_write_data_link[plic_num_src_min_32_node:1];
          plic_inten01_node:        if (`CFG_PLIC_NUM_SRC >= 32) int_en_node[(plic_src_bot_node-1) +: ((plic_src_top_node)-(plic_src_bot_node)+1)]         <= uart_write_data_link[plic_src_dintop_node:0];
          plic_threshold0_node:     int_threshold_node[0 +:3]         <= uart_write_data_link[2:0];
          plic_claimcomplete0_node: begin
            // Ignore zero, out-of-range and sources not enabled for this
            // target.  In particular, do not truncate a larger ID to 6 bits.
            if ((uart_write_data_link != 0) & (uart_write_data_link <= `CFG_PLIC_NUM_SRC)) begin
              if (int_en_node[(complete_id_node-1)])
                int_in_progress_node <= int_in_progress_node & ~(one_node << (complete_id_node-1));
            end
          end
        endcase

      // Read synchronously because a read can have side effect of changing int_in_progress_node
      if (memread_node) begin
        casez(entry_node)
          plic_intpriority0_node: uart_read_data_link <= 32'b0;  // there is no int_priority_node[0]
          24'h0000??:
            if ((priority_entry_index_node != 0) & (priority_entry_index_node <= `CFG_PLIC_NUM_SRC))
              uart_read_data_link <= {29'b0,int_priority_node[((priority_entry_index_node-1))*3 +:3]};
            else uart_read_data_link <= 32'b0;
          plic_intpending0_node:  uart_read_data_link <= {{(31-plic_num_src_min_32_node){1'b0}},int_pending_node[plic_num_src_min_32_node:1],1'b0};
          plic_inten00_node:      uart_read_data_link <= {{(31-plic_num_src_min_32_node){1'b0}},int_en_node[0 +: ((plic_num_src_min_32_node)-(1)+1)],1'b0};
          plic_intpending1_node:  if (`CFG_PLIC_NUM_SRC >= 32) uart_read_data_link <= {{(plic_src_ext_node){1'b0}},int_pending_node[plic_src_top_node:plic_src_bot_node]};
          plic_inten01_node:      if (`CFG_PLIC_NUM_SRC >= 32) uart_read_data_link <= {{(plic_src_ext_node){1'b0}},int_en_node[(plic_src_bot_node-1) +: ((plic_src_top_node)-(plic_src_bot_node)+1)]};
          plic_threshold0_node:   uart_read_data_link <= {29'b0,int_threshold_node[0 +:3]};
          plic_claimcomplete0_node: begin
            uart_read_data_link <= {26'b0,int_claim_node[0 +:6]};
            if (int_claim_node[0 +:6] != 6'd0) // not an invalid request
              int_in_progress_node <= int_in_progress_node | (one_node << (int_claim_node[0 +:6]-1)); // claimed requests are currently in progress of being serviced until they are completed
          end
          default:           uart_read_data_link <= 32'h0; // invalid access
        endcase
      end else               uart_read_data_link <= 32'h0;
   end
  end

  // connect sources to requests
  // Continuous per-source wiring also defines requests when both source IDs are 0.
  // UART has priority if the two configured interrupt IDs coincide.
  genvar request_src_node;
  for (request_src_node = 1; request_src_node <= `CFG_PLIC_NUM_SRC;
       request_src_node = request_src_node + 1) begin : request_wiring
    assign requests_node[request_src_node] =
        (`CFG_PLIC_UART_ID == request_src_node) ? uart_intr_link :
        (`CFG_PLIC_GPIO_ID == request_src_node) ? gpio_intr_link : 1'b0;
  end

  // pending interrupt request
  assign next_int_pending_node = (int_pending_node | requests_node) & ~int_in_progress_node;
  ffr #(`CFG_PLIC_NUM_SRC) interrupt_pending_ff_u(pclk_link,~prese_tn_link,next_int_pending_node,int_pending_node);

  // context-dependent signals
  genvar ctx_node;
  for (ctx_node=0; ctx_node<`C; ctx_node = ctx_node + 1) begin
    // request matrix
    //   priority level (rows) X source ID (columns)
    //
    //   irq_matrix_node[ctx][pri][src] is high if source <src>
    //   has priority level <pri> and has an "active" interrupt request
    //   ("active" meaning it is enabled in context <ctx> and is pending)
    genvar src_node, pri;
    for (pri=1; pri<=7; pri = pri + 1) begin
      for (src_node=1; src_node<=`CFG_PLIC_NUM_SRC; src_node = src_node + 1) begin
        assign irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+((pri-1))*`CFG_PLIC_NUM_SRC+(src_node-1)] = (int_priority_node[((src_node-1))*3 +:3]==pri) & int_pending_node[src_node] & int_en_node[(ctx_node)*`CFG_PLIC_NUM_SRC+(src_node-1)];
      end
    end

    // which priority levels have one or more active requests?
    assign priorities_with_irqs_node[(ctx_node)*7 +:7] = {
      |irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(6)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC],
      |irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(5)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC],
      |irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(4)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC],
      |irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(3)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC],
      |irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(2)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC],
      |irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(1)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC],
      |irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC]
    };

    // get the highest priority level that has active requests
    assign max_priority_with_irqs_node[(ctx_node)*7 +:7] = {
      priorities_with_irqs_node[(ctx_node)*7+6],
      priorities_with_irqs_node[(ctx_node)*7+5] & ~|priorities_with_irqs_node[(ctx_node)*7+6],
      priorities_with_irqs_node[(ctx_node)*7+4] & ~|priorities_with_irqs_node[(ctx_node)*7+5 +:2],
      priorities_with_irqs_node[(ctx_node)*7+3] & ~|priorities_with_irqs_node[(ctx_node)*7+4 +:3],
      priorities_with_irqs_node[(ctx_node)*7+2] & ~|priorities_with_irqs_node[(ctx_node)*7+3 +:4],
      priorities_with_irqs_node[(ctx_node)*7+1] & ~|priorities_with_irqs_node[(ctx_node)*7+2 +:5],
      priorities_with_irqs_node[(ctx_node)*7] & ~|priorities_with_irqs_node[(ctx_node)*7+1 +:6]
    };

    // of the sources at the highest priority level that has active requests,
    // which sources have active requests?
    assign irqs_at_max_priority_node[(ctx_node)*`CFG_PLIC_NUM_SRC +: ((`CFG_PLIC_NUM_SRC)-(1)+1)] =
      ({`CFG_PLIC_NUM_SRC{max_priority_with_irqs_node[(ctx_node)*7+6]}} & irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(6)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC]) |
      ({`CFG_PLIC_NUM_SRC{max_priority_with_irqs_node[(ctx_node)*7+5]}} & irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(5)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC]) |
      ({`CFG_PLIC_NUM_SRC{max_priority_with_irqs_node[(ctx_node)*7+4]}} & irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(4)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC]) |
      ({`CFG_PLIC_NUM_SRC{max_priority_with_irqs_node[(ctx_node)*7+3]}} & irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(3)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC]) |
      ({`CFG_PLIC_NUM_SRC{max_priority_with_irqs_node[(ctx_node)*7+2]}} & irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(2)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC]) |
      ({`CFG_PLIC_NUM_SRC{max_priority_with_irqs_node[(ctx_node)*7+1]}} & irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC+(1)*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC]) |
      ({`CFG_PLIC_NUM_SRC{max_priority_with_irqs_node[(ctx_node)*7]}} & irq_matrix_node[(ctx_node)*7*`CFG_PLIC_NUM_SRC +: `CFG_PLIC_NUM_SRC]);

    // create threshold mask
    always @* begin
      thresh_mask_node[(ctx_node)*7+6] = (int_threshold_node[(ctx_node)*3 +:3] != 7);
      thresh_mask_node[(ctx_node)*7+5] = (int_threshold_node[(ctx_node)*3 +:3] != 6) & thresh_mask_node[(ctx_node)*7+6];
      thresh_mask_node[(ctx_node)*7+4] = (int_threshold_node[(ctx_node)*3 +:3] != 5) & thresh_mask_node[(ctx_node)*7+5];
      thresh_mask_node[(ctx_node)*7+3] = (int_threshold_node[(ctx_node)*3 +:3] != 4) & thresh_mask_node[(ctx_node)*7+4];
      thresh_mask_node[(ctx_node)*7+2] = (int_threshold_node[(ctx_node)*3 +:3] != 3) & thresh_mask_node[(ctx_node)*7+3];
      thresh_mask_node[(ctx_node)*7+1] = (int_threshold_node[(ctx_node)*3 +:3] != 2) & thresh_mask_node[(ctx_node)*7+2];
      thresh_mask_node[(ctx_node)*7] = (int_threshold_node[(ctx_node)*3 +:3] != 1) & thresh_mask_node[(ctx_node)*7+1];
    end

    // of the sources at the highest priority level that has active requests,
    // choose the source with the lowest source ID to be the most urgent
    // and set int_claim_node to the source ID of the most urgent active request
    integer k_node;
    always @* begin
      int_claim_node[(ctx_node)*6 +:6] = 6'b0;
      for (k_node=`CFG_PLIC_NUM_SRC; k_node>0; k_node = k_node - 1) begin
        if (irqs_at_max_priority_node[(ctx_node)*`CFG_PLIC_NUM_SRC+(k_node-1)]) int_claim_node[(ctx_node)*6 +:6] = k_node[5:0];
      end
    end
  end
  // is the max priority > threshold?
  // would it be any better to first priority encode maxPriority into binary and then ">" with threshold?
  assign m_ext_int_link = |(thresh_mask_node[0 +:7] & priorities_with_irqs_node[0 +:7]);
endmodule
