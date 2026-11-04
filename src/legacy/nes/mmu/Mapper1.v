// MMC1 mapper chip. Maps prg or chr addresses into a linear address.
// If vram_ce is set, {vram_a10, chr_aout[9:0]} are used to access the NES internal VRAM instead.
module Mapper1(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [18:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [18:0] chr_aout,
            output chr_allow,                      // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [4:0] shift;
  
// CPPMM
// |||||
// |||++- Mirroring (0: one-screen, lower bank; 1: one-screen, upper bank;
// |||               2: vertical; 3: horizontal)
// |++--- PRG ROM bank mode (0, 1: switch 32 KB at $8000, ignoring low bit of bank number;
// |                         2: fix first bank at $8000 and switch 16 KB bank at $C000;
// |                         3: fix last bank at $C000 and switch 16 KB bank at $8000)
// +----- CHR ROM bank mode (0: switch 8 KB at a time; 1: switch two separate 4 KB banks)
  reg [4:0] control;

// CCCCC
// |||||
// +++++- Select 4 KB or 8 KB CHR bank at PPU $0000 (low bit ignored in 8 KB mode)
  reg [4:0] chr_bank_0;

// CCCCC
// |||||
// +++++- Select 4 KB CHR bank at PPU $1000 (ignored in 8 KB mode)
  reg [4:0] chr_bank_1;
  
// RPPPP
// |||||
// |++++- Select 16 KB PRG ROM bank (low bit ignored in 32 KB mode)
// +----- PRG RAM chip enable (0: enabled; 1: disabled; ignored on MMC1A)
  reg [4:0] prg_bank;

  // MMC1 ignores a second register write on the immediately following CPU
  // cycle.  This is required for read-modify-write instructions: without the
  // guard, one CPU instruction can clock two bits into the serial register
  // and corrupt the selected PRG/CHR bank.
  reg delay_ctrl;
  
  // Update shift register
  always @(posedge clk or posedge reset)
  if (reset) begin
    // MMC1 accepts one configuration bit per CPU write.  The sentinel must
    // start in bit 4; starting at 5'b00001 makes the very first write look
    // like the fifth write and commits an incomplete register value.
    shift <= 5'b10000;
    control <= 'hC;

    chr_bank_0 <= 'b0;
    chr_bank_1 <= 'b0;
    prg_bank    <= 'b0;
    delay_ctrl  <= 1'b0;

  end else if (ce) begin
    // Re-arm only after the CPU write strobe has gone inactive.
    if (!prg_write)
      delay_ctrl <= 1'b0;

    if (prg_write && prg_ain[15] && !delay_ctrl) begin
      delay_ctrl <= 1'b1;
      if (prg_din[7]) begin
        shift <= 5'b10000;
        control <= control | 'hC;
//        $write("MMC1 RESET!\n");
      end else begin
        if (shift[0]) begin
//          $write("MMC1 WRITE %X to %X!\n", {prg_din[0], shift[4:1]}, prg_ain);
          casez(prg_ain[14:13])
          0: control    <= {prg_din[0], shift[4:1]};
          1: chr_bank_0 <= {prg_din[0], shift[4:1]};
          2: chr_bank_1 <= {prg_din[0], shift[4:1]};
          3: prg_bank   <= {prg_din[0], shift[4:1]};
          endcase
          shift <= 5'b10000;
        end else begin
          shift <= {prg_din[0], shift[4:1]};
        end
      end
    end
  end
  
  // The PRG bank to load. Each increment here is 16kb. So valid values are 0..15.
  reg [3:0] prgsel;
  always @* begin
    casez({control[3:2], prg_ain[14]})
    3'b0?_?: prgsel = {prg_bank[3:1], prg_ain[14]};
    3'b10_0: prgsel = 4'b0000;
    3'b10_1: prgsel = prg_bank[3:0];
    3'b11_0: prgsel = prg_bank[3:0];
    3'b11_1: prgsel = 4'b1111;
    endcase
  end
  wire [18:0] prg_aout_tmp = {1'b0, prgsel, prg_ain[13:0]};

  // The CHR bank to load. Each increment here is 4 kb. So valid values are 0..31.
  reg [4:0] chrsel;
  always @* begin
    casez({control[4], chr_ain[12]})
    2'b0_?: chrsel = {chr_bank_0[4:1], chr_ain[12]};
    2'b1_0: chrsel = chr_bank_0;
    2'b1_1: chrsel = chr_bank_1;
    endcase
  end
  assign chr_aout = {2'b10, chrsel, chr_ain[11:0]};
  
  // The a10 VRAM address line. (Used for mirroring)
  reg vram_a10_t;
  always @* begin
    case(control[1:0])
    2'b00: vram_a10_t = 0;             // One screen, lower bank
    2'b01: vram_a10_t = 1;             // One screen, upper bank
    2'b10: vram_a10_t = chr_ain[10];   // One screen, vertical
    2'b11: vram_a10_t = chr_ain[11];   // One screen, horizontal
    endcase
  end
  assign vram_a10 = vram_a10_t;
  assign vram_ce = chr_ain[13];
  
  wire prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000;
  assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram;
  wire [18:0] prg_ram = {6'b11_1100, prg_ain[12:0]};
  
  assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;
  assign chr_allow = flags[15];


endmodule
