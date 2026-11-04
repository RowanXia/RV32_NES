// Sample a peripheral interrupt level through two CPU-domain flip-flops.
// Keep meta_ff and sync_ff aligned with the board timing constraints.
module rv32_level_sync (
  input  wire clk,
  input  wire reset_n,
  input  wire async_level,
  output wire sync_level
);
  wire meta_level;
  GTP_DFF_C meta_ff(.CLK(clk), .C(~reset_n), .D(async_level), .Q(meta_level));
  GTP_DFF_C sync_ff(.CLK(clk), .C(~reset_n), .D(meta_level), .Q(sync_level));
endmodule
