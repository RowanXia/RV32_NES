// Single-outstanding AHB-Lite clock-domain bridge.  Address/control are
// accepted in the source address phase.  HWDATA and HSTRB are deliberately
// captured one source cycle later, in the matching data phase.  Both bundled
// payloads remain stable for the complete toggle-handshake round trip.
module rv32_ahb_async_bridge (
  input  wire        s_clk,
  input  wire        s_reset_n,
  input  wire        s_hsel,
  input  wire        s_hready,
  input  wire [31:0] s_haddr,
  input  wire [1:0]  s_htrans,
  input  wire        s_hwrite,
  input  wire [2:0]  s_hsize,
  input  wire [3:0]  s_hprot,
  input  wire [31:0] s_hwdata,
  input  wire [3:0]  s_hwstrb,
  output wire [31:0] s_hrdata,
  output wire        s_hreadyout,
  output wire        s_hresp,

  input  wire        m_clk,
  input  wire        m_reset_n,
  output wire [31:0] m_haddr,
  output wire [1:0]  m_htrans,
  output wire        m_hwrite,
  output wire [2:0]  m_hsize,
  output wire [2:0]  m_hburst,
  output wire [3:0]  m_hprot,
  output wire [31:0] m_hwdata,
  output wire [3:0]  m_hwstrb,
  input  wire [31:0] m_hrdata,
  input  wire        m_hready,
  input  wire        m_hresp
);
  localparam [2:0] S_IDLE    = 3'd0;
  localparam [2:0] S_CAPTURE = 3'd1;
  localparam [2:0] S_WAIT    = 3'd2;
  localparam [2:0] S_REPLY   = 3'd3;
  localparam [2:0] S_ERR1    = 3'd4;
  localparam [2:0] S_DONE    = 3'd5;
  localparam [1:0] M_IDLE    = 2'd0;
  localparam [1:0] M_CAPTURE = 2'd1;
  localparam [1:0] M_ADDR    = 2'd2;
  localparam [1:0] M_DATA    = 2'd3;

  reg [2:0] source_state;
  reg [1:0] target_state;
  reg [31:0] address_q;
  reg write_q;
  reg [2:0] size_q;
  reg [3:0] prot_q;
  reg request_toggle;
  reg acknowledge_toggle;
  reg acknowledge_sync;
  reg request_sync;
  reg request_delay;
  wire acknowledge_meta;
  wire request_meta;

  // Only the first stage of each toggle synchronizer is asynchronous.
  GTP_DFF_C acknowledge_meta_ff(
    .CLK(s_clk), .C(~s_reset_n), .D(acknowledge_toggle), .Q(acknowledge_meta));
  GTP_DFF_C request_meta_ff(
    .CLK(m_clk), .C(~m_reset_n), .D(request_toggle), .Q(request_meta));

  always @(posedge s_clk or negedge s_reset_n)
    if (!s_reset_n)
      acknowledge_sync <= 1'b0;
    else
      acknowledge_sync <= acknowledge_meta;

  always @(posedge m_clk or negedge m_reset_n)
    if (!m_reset_n) begin
      request_sync <= 1'b0;
      request_delay <= 1'b0;
    end else begin
      request_sync <= request_meta;
      request_delay <= request_sync;
    end

  // Address/control came from the accepted address phase.  Write data and
  // byte strobes are sampled only in S_CAPTURE, the corresponding data phase.
  wire [75:0] request_input = {
    prot_q, size_q, write_q, address_q, s_hwstrb, s_hwdata
  };
  wire [75:0] request_hold;
  wire [75:0] request_captured;
  wire [32:0] response_input = {m_hresp, m_hrdata};
  wire [32:0] response_hold;
  wire [32:0] response_captured;
  wire take_reply = (source_state == S_WAIT) &&
                    (acknowledge_sync == request_toggle);

  genvar payload_bit;
  generate
    for (payload_bit = 0; payload_bit < 76; payload_bit = payload_bit + 1) begin : request_payload
      GTP_DFF_CE held_ff(
        .CLK(s_clk), .C(~s_reset_n), .CE(source_state == S_CAPTURE),
        .D(request_input[payload_bit]), .Q(request_hold[payload_bit]));
      GTP_DFF_CE capture_ff(
        .CLK(m_clk), .C(~m_reset_n), .CE(target_state == M_CAPTURE),
        .D(request_hold[payload_bit]), .Q(request_captured[payload_bit]));
    end
    for (payload_bit = 0; payload_bit < 33; payload_bit = payload_bit + 1) begin : response_payload
      GTP_DFF_CE held_ff(
        .CLK(m_clk), .C(~m_reset_n),
        .CE((target_state == M_DATA) && m_hready),
        .D(response_input[payload_bit]), .Q(response_hold[payload_bit]));
      GTP_DFF_CE capture_ff(
        .CLK(s_clk), .C(~s_reset_n), .CE(take_reply),
        .D(response_hold[payload_bit]), .Q(response_captured[payload_bit]));
    end
  endgenerate

  assign {m_hprot, m_hsize, m_hwrite, m_haddr, m_hwstrb, m_hwdata} =
         request_captured;
  assign m_htrans = (target_state == M_ADDR) ? 2'b10 : 2'b00;
  assign m_hburst = 3'b000;
  assign s_hrdata = response_captured[31:0];
  assign s_hreadyout = (source_state == S_IDLE) || (source_state == S_DONE);
  assign s_hresp = (source_state == S_ERR1) ||
                   ((source_state == S_DONE) && response_captured[32]);

  wire source_accept = s_hsel && s_htrans[1] && s_hready;

  always @(posedge s_clk or negedge s_reset_n) begin
    if (!s_reset_n) begin
      source_state <= S_IDLE;
      address_q <= 32'b0;
      write_q <= 1'b0;
      size_q <= 3'b0;
      prot_q <= 4'b0;
      request_toggle <= 1'b0;
    end else begin
      case (source_state)
        S_IDLE, S_DONE: begin
          if (source_accept) begin
            address_q <= s_haddr;
            write_q <= s_hwrite;
            size_q <= s_hsize;
            prot_q <= s_hprot;
            source_state <= S_CAPTURE;
          end else begin
            source_state <= S_IDLE;
          end
        end
        S_CAPTURE: begin
          request_toggle <= ~request_toggle;
          source_state <= S_WAIT;
        end
        S_WAIT:
          if (take_reply)
            source_state <= S_REPLY;
        S_REPLY:
          source_state <= response_captured[32] ? S_ERR1 : S_DONE;
        S_ERR1:
          source_state <= S_DONE;
        default:
          source_state <= S_IDLE;
      endcase
    end
  end

  always @(posedge m_clk or negedge m_reset_n) begin
    if (!m_reset_n) begin
      target_state <= M_IDLE;
      acknowledge_toggle <= 1'b0;
    end else begin
      case (target_state)
        M_IDLE:
          if (request_delay != acknowledge_toggle)
            target_state <= M_CAPTURE;
        M_CAPTURE:
          target_state <= M_ADDR;
        M_ADDR:
          if (m_hready)
            target_state <= M_DATA;
        M_DATA:
          if (m_hready) begin
            acknowledge_toggle <= request_delay;
            target_state <= M_IDLE;
          end
        default:
          target_state <= M_IDLE;
      endcase
    end
  end
endmodule
