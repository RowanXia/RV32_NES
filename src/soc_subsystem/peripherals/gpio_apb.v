// Module role: Implements APB-mapped GPIO input, output and interrupt configuration.
// Behavioral interface: The peripheral aggregates configured pin events into one PLIC-facing request.

`include "../config.vh"

module gpio_apb    (
  input wire pclk_link,
  input wire prese_tn_link,
  input wire psel_link,
  input wire [7:0] paddr_link,
  input wire [31:0] pwdata_link,
  input wire [3:0] pstrb_link,
  input wire pwrite_link,
  input wire penable_link,
  output wire [31:0] prdata_link,
  output wire pready_link,
  input wire [31:0] iof0_link,
  input wire [31:0] iof1_link,
  input wire [31:0] gpioin_link,
  output wire [31:0] gpioout_link,
  output wire [31:0] gpioen_link,
  output wire gpio_intr_link
);

  // APB address decoding for GPIO control and status registers.
  localparam gpio_input_val_node  = 8'h00;
  localparam gpio_input_en_node   = 8'h04;
  localparam gpio_output_en_node  = 8'h08;
  localparam gpio_output_val_node = 8'h0C;
  localparam gpio_rise_ie_node    = 8'h18;
  localparam gpio_rise_ip_node    = 8'h1C;
  localparam gpio_fall_ie_node    = 8'h20;
  localparam gpio_fall_ip_node    = 8'h24;
  localparam gpio_high_ie_node    = 8'h28;
  localparam gpio_high_ip_node    = 8'h2C;
  localparam gpio_low_ie_node     = 8'h30;
  localparam gpio_low_ip_node     = 8'h34;
  localparam gpio_iof_en_node     = 8'h38;
  localparam gpio_iof_sel_node    = 8'h3C;
  localparam gpio_out_xor_node    = 8'h40;

  wire [31:0] input0d_node;
  wire [31:0] input1d_node;
  wire [31:0] input2d_node;
  wire [31:0] input3d_node;
  wire [31:0] input_val_node;
  reg [31:0] input_en_node;
  reg [31:0] output_en_node;
  reg [31:0] output_val_node;
  reg [31:0] rise_ie_node;
  reg [31:0] rise_ip_node;
  reg [31:0] fall_ie_node;
  reg [31:0] fall_ip_node;
  reg [31:0] high_ie_node;
  reg [31:0] high_ip_node;
  reg [31:0] low_ie_node;
  reg [31:0] low_ip_node;
  reg [31:0] out_xor_node;
  reg [31:0] iof_en_node;
  reg [31:0] iof_sel_node;
  wire [31:0] iof_out_node;
  wire [31:0] gpio_out_node;
  wire [7:0] entry_node;
  wire [31:0] uart_write_data_link;
  reg [31:0] uart_read_data_link;
  wire memwrite_node;

  // APB I/O
  assign entry_node    = {paddr_link[7:2],2'b00};       // 32-bit word-aligned accesses
  assign memwrite_node = pwrite_link & penable_link & psel_link;  // only write in access phase
  assign pready_link   = 1'b1;                     // GPIO never takes >1 cycle to respond

  // account for subword read/write circuitry
  // -- Note GPIO registers are 32 bits no matter what; access them with LW SW.
  assign uart_write_data_link = pwdata_link[31:0];
  assign prdata_link = uart_read_data_link;

  // Collapse all enabled pending sources into the single PLIC-facing request.
  assign gpio_intr_link = |{(rise_ip_node & rise_ie_node),(fall_ip_node & fall_ie_node),(high_ip_node & high_ie_node),(low_ip_node & low_ie_node)};

  // register access
  always @(posedge pclk_link)
    if (~prese_tn_link) begin
      input_en_node  <= 1'b0;
      output_en_node <= 1'b0;
      output_val_node <= 1'b0;
      rise_ie_node    <= 1'b0;
      rise_ip_node    <= 1'b0;
      fall_ie_node    <= 1'b0;
      fall_ip_node    <= 1'b0;
      high_ie_node    <= 1'b0;
      high_ip_node    <= 1'b0;
      low_ie_node     <= 1'b0;
      low_ip_node     <= 1'b0;
      iof_en_node     <= 1'b0;
      iof_sel_node    <= 1'b0;
      out_xor_node    <= 1'b0;
    end else begin     // writes
        // According to FE310 spec: Once the interrupt is pending, it will remain set until a 1 is written to the *_ip register at that bit.
        /* verilator lint_off CASEINCOMPLETE */
      if (memwrite_node)
        case(entry_node)
          gpio_input_en_node:   input_en_node   <= uart_write_data_link;
          gpio_output_en_node:  output_en_node  <= uart_write_data_link;
          gpio_output_val_node: output_val_node <= uart_write_data_link;
          gpio_rise_ie_node:    rise_ie_node    <= uart_write_data_link;
          gpio_fall_ie_node:    fall_ie_node    <= uart_write_data_link;
          gpio_high_ie_node:    high_ie_node    <= uart_write_data_link;
          gpio_low_ie_node:     low_ie_node     <= uart_write_data_link;
          gpio_iof_en_node:     iof_en_node     <= uart_write_data_link;
          gpio_iof_sel_node:    iof_sel_node    <= uart_write_data_link;
          gpio_out_xor_node:    out_xor_node    <= uart_write_data_link;
        endcase
        /* verilator lint_on CASEINCOMPLETE */

      // interrupts can be cleared by writing corresponding bits to a register
      if (memwrite_node & entry_node == gpio_rise_ip_node)   rise_ip_node <= rise_ip_node & ~uart_write_data_link;
      else                                    rise_ip_node <= rise_ip_node | (input2d_node & ~input3d_node);
      if (memwrite_node & (entry_node == gpio_fall_ip_node)) fall_ip_node <= fall_ip_node & ~uart_write_data_link;
      else                                    fall_ip_node <= fall_ip_node | (~input2d_node & input3d_node);
      if (memwrite_node & (entry_node == gpio_high_ip_node)) high_ip_node <= high_ip_node & ~uart_write_data_link;
      else                                    high_ip_node <= high_ip_node | input3d_node;
      if (memwrite_node & (entry_node == gpio_low_ip_node))  low_ip_node  <= low_ip_node  & ~uart_write_data_link;
      else                                    low_ip_node  <= low_ip_node  | ~input3d_node;

      case(entry_node) // flop to sample inputs
        gpio_input_val_node:   uart_read_data_link <= input_val_node;
        gpio_input_en_node:    uart_read_data_link <= input_en_node;
        gpio_output_en_node:   uart_read_data_link <= output_en_node;
        gpio_output_val_node:  uart_read_data_link <= output_val_node;
        gpio_rise_ie_node:     uart_read_data_link <= rise_ie_node;
        gpio_rise_ip_node:     uart_read_data_link <= rise_ip_node;
        gpio_fall_ie_node:     uart_read_data_link <= fall_ie_node;
        gpio_fall_ip_node:     uart_read_data_link <= fall_ip_node;
        gpio_high_ie_node:     uart_read_data_link <= high_ie_node;
        gpio_high_ip_node:     uart_read_data_link <= high_ip_node;
        gpio_low_ie_node:      uart_read_data_link <= low_ie_node;
        gpio_low_ip_node:      uart_read_data_link <= low_ip_node;
        gpio_iof_en_node:      uart_read_data_link <= iof_en_node;
        gpio_iof_sel_node:     uart_read_data_link <= iof_sel_node;
        gpio_out_xor_node:     uart_read_data_link <= out_xor_node;
        default:          uart_read_data_link <= 1'b0;
      endcase
    end

  // chip i/o
  // connect OUT to IN for loopback testing
  if (`CFG_GPIO_LOOPBACK_TEST) assign input0d_node = ((output_en_node & gpioout_link) | (~output_en_node & gpioin_link)) & input_en_node;
  else                      assign input0d_node = gpioin_link & input_en_node;

  // synchroninzer for inputs
  ff #(32) sync3_u(pclk_link,input2d_node,input3d_node);
  ff #(32) sync2_u(pclk_link,input1d_node,input2d_node);
  ff #(32) sync1_u(pclk_link,input0d_node,input1d_node);
  assign input_val_node = input3d_node;
  assign iof_out_node   = iof_sel_node & iof1_link | ~iof_sel_node & iof0_link;        // per-bit mux between iof1 and iof0
  assign gpio_out_node  = iof_en_node & iof_out_node | ~iof_en_node & output_val_node; // per-bit mux between IOF and output_val
  assign gpioout_link   = gpio_out_node ^ out_xor_node;                      // per-bit flip output polarity
  assign gpioen_link    = output_en_node;

endmodule
