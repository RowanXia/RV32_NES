// Synchronize an active-low button and require a stable change for COUNTER_MAX cycles.
// Keep key_meta_ff named consistently with the asynchronous input constraint.
// Terminal-count clearing overrides the earlier increment in the same process.
module Button_Debounce #(
     
    parameter CLK_FREQ = 21_000_000,   
    parameter DEBOUNCE_TIME = 10       
)(
    input clk,
    input rst_n,
    input key_in,
    output reg key_out
);

localparam COUNTER_MAX = CLK_FREQ / 1000 * DEBOUNCE_TIME;   

reg [19:0] counter;       
wire key_sync0;
GTP_DFF_P key_meta_ff(.CLK(clk),.P(~rst_n),.D(key_in),.Q(key_sync0));            
reg key_sync1;            
reg key_stable;           

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin

        key_sync1 <= 1'b1;
    end else begin

        key_sync1 <= key_sync0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter <= 20'd0;
        key_stable <= 1'b1;
        key_out <= 1'b1;
    end else begin
         
        if (key_stable != key_sync1) begin
            counter <= counter + 20'd1;
            if (counter == COUNTER_MAX - 1) begin
                key_stable <= key_sync1;
                key_out <= key_sync1;
                counter <= 20'd0;
            end
        end else begin
            counter <= 20'd0;
            key_out <= key_stable;
        end
    end
end

endmodule
