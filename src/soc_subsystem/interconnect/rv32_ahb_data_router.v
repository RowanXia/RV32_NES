// Split the CPU AHB address phase between local RAM, local performance MMIO,
// and the peripheral CDC bridge. The selected target is registered so that the
// response mux follows the AHB data phase rather than the next address.
`include "../config.vh"

module rv32_ahb_data_router (
  input  wire        clk,
  input  wire        reset_n,
  input  wire [31:0] cpu_haddr,
  input  wire [1:0]  cpu_htrans,
  input  wire        cpu_hready,

  input  wire [31:0] ram_hrdata,
  input  wire        ram_hready,
  input  wire        ram_hresp,
  input  wire [31:0] perf_hrdata,
  input  wire        perf_hready,
  input  wire        perf_hresp,
  input  wire [31:0] io_hrdata,
  input  wire        io_hready,
  input  wire        io_hresp,

  output wire        ram_hsel,
  output wire        perf_hsel,
  output wire        io_hsel,
  output wire [31:0] cpu_hrdata,
  output wire        cpu_hreadyout,
  output wire        cpu_hresp
);
  localparam [31:0] RAM_LIMIT = `CFG_UNCORE_RAM_BASE + `CFG_UNCORE_RAM_BYTES;
  localparam [1:0] TARGET_RAM  = 2'b00;
  localparam [1:0] TARGET_PERF = 2'b01;
  localparam [1:0] TARGET_IO   = 2'b10;

  wire address_phase_valid = cpu_htrans[1];
  wire address_is_ram = (cpu_haddr >= `CFG_UNCORE_RAM_BASE) &&
                        (cpu_haddr < RAM_LIMIT);
  wire address_is_perf = (cpu_haddr >= `CFG_PERF_BASE) &&
                         (cpu_haddr <= (`CFG_PERF_BASE + `CFG_PERF_RANGE));
  wire [1:0] address_target = address_is_ram ? TARGET_RAM :
                              (address_is_perf ? TARGET_PERF : TARGET_IO);
  reg [1:0] data_phase_target;

  assign ram_hsel  = address_phase_valid && (address_target == TARGET_RAM);
  assign perf_hsel = address_phase_valid && (address_target == TARGET_PERF);
  assign io_hsel   = address_phase_valid && (address_target == TARGET_IO);

  assign cpu_hrdata = (data_phase_target == TARGET_RAM) ? ram_hrdata :
                      (data_phase_target == TARGET_PERF) ? perf_hrdata : io_hrdata;
  assign cpu_hreadyout = (data_phase_target == TARGET_RAM) ? ram_hready :
                         (data_phase_target == TARGET_PERF) ? perf_hready : io_hready;
  assign cpu_hresp = (data_phase_target == TARGET_RAM) ? ram_hresp :
                     (data_phase_target == TARGET_PERF) ? perf_hresp : io_hresp;

  // Advance the response owner only for a valid accepted address phase. IDLE
  // and BUSY cycles leave the current data-phase owner unchanged.
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n)
      data_phase_target <= TARGET_RAM;
    else if (cpu_hready && address_phase_valid)
      data_phase_target <= address_target;
  end
endmodule
