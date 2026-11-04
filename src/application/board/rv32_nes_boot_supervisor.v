// Modified for RV32 NES integration, 2026-11-01.
// Begin the startup budget after the CPU hands control to the game application.
// Retry once by holding reset; a second expiration latches boot_failed.
module rv32_nes_boot_supervisor #(
 parameter integer BOOT_CYCLES=214400000,
 parameter integer RETRY_HOLD_CYCLES=428800,
 // Keep the final NES_READY UART marker ahead of the one-shot handoff reset.
 parameter integer HANDOFF_SETTLE_CYCLES=4288000
)(
 input clk,base_rst_n,handoff,menu_ready,
 output wire rst_n,output reg retry_used,output reg boot_failed
);
 localparam integer BW=(BOOT_CYCLES<2)?1:$clog2(BOOT_CYCLES);
 localparam integer RW=(RETRY_HOLD_CYCLES<2)?1:$clog2(RETRY_HOLD_CYCLES);
 localparam integer HW=(HANDOFF_SETTLE_CYCLES<2)?1:$clog2(HANDOFF_SETTLE_CYCLES);
 reg [BW-1:0] elapsed;
 reg [RW-1:0] hold_count;
 reg [HW-1:0] handoff_wait_count;
 reg recovering,boot_done,armed,handoff_recovery_done,handoff_recovery_pending;
 // Priority: base reset, reset hold, first-handoff settle, completed menu,
 // then startup timeout.  The one-shot reset reproduces the known-good KEY0
 // reset boundary without re-running CoreMark or the UART exchange.
 always @(posedge clk or negedge base_rst_n) begin
  if(!base_rst_n) begin
   elapsed<=0;hold_count<=0;handoff_wait_count<=0;
   recovering<=0;boot_done<=0;armed<=0;
   handoff_recovery_done<=0;handoff_recovery_pending<=0;
   retry_used<=0;boot_failed<=0;
  end else if(recovering) begin
   elapsed<=0;
   if(hold_count==RETRY_HOLD_CYCLES-1) begin recovering<=0;hold_count<=0;end
   else hold_count<=hold_count+1'b1;
  end else if(handoff && !handoff_recovery_done) begin
   // Start the 100 ms grace period after software asserts game_mode.
   handoff_recovery_done<=1; handoff_recovery_pending<=1;
   handoff_wait_count<=0; armed<=1; elapsed<=0;
  end else if(handoff_recovery_pending) begin
   // At 42.88 MHz this is 100 ms; then reset for RETRY_HOLD_CYCLES (10 ms).
   if(handoff_wait_count==HANDOFF_SETTLE_CYCLES-1) begin
    handoff_recovery_pending<=0; recovering<=1; hold_count<=0;
   end else handoff_wait_count<=handoff_wait_count+1'b1;
  end else if(menu_ready && (armed || handoff)) begin
   boot_done<=1;elapsed<=0;
  end else if(!boot_done && !boot_failed) begin
   if(handoff) armed<=1;
   if(armed || handoff) begin
    if(elapsed==BOOT_CYCLES-1) begin
     elapsed<=0;
     if(!retry_used) begin retry_used<=1;recovering<=1;hold_count<=0;end
     else boot_failed<=1;
    end else elapsed<=elapsed+1'b1;
   end
  end
 end

 // Reset assertion follows recovering without an extra clock of latency.
 assign rst_n=base_rst_n && !recovering;
endmodule
