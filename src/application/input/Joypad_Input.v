// Decode two-byte controller snapshots and individual button edges.
// Received bytes take precedence over timeout clearing in the same cycle.
module Joypad_Input #(
    parameter CLK_HZ = 42884160,
    parameter TIMEOUT_CYCLES = CLK_HZ / 2,
    parameter FRAME_CYCLES = CLK_HZ / 100
) (
    input clk, input rst_n,
    input [7:0] rx_data, input rx_valid, input enable,
    output reg [7:0] p1, output reg [7:0] p2
);
    reg [3:0] pending_low;
    reg [1:0] pending_player;
    reg snapshot1, snapshot2;
    reg [31:0] age1, age2;
    reg [31:0] frame_age;
    reg [7:0] button_mask;
    // Keep all assignments to pending_player and frame_age in this process:
    // later receive handling deliberately overrides expiration handling.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p1 <= 0; p2 <= 0; pending_low <= 0; pending_player <= 0;
            snapshot1 <= 0; snapshot2 <= 0; age1 <= 0; age2 <= 0;
            frame_age <= 0;
        end else if (!enable) begin
            p1 <= 0; p2 <= 0; pending_low <= 0; pending_player <= 0;
            snapshot1 <= 0; snapshot2 <= 0; age1 <= 0; age2 <= 0;
            frame_age <= 0;
        end else begin
            if (snapshot1 && age1 < TIMEOUT_CYCLES) age1 <= age1 + 1;
            if (snapshot2 && age2 < TIMEOUT_CYCLES) age2 <= age2 + 1;
            if (snapshot1 && age1 >= TIMEOUT_CYCLES-1) begin p1 <= 0; snapshot1 <= 0; end
            if (snapshot2 && age2 >= TIMEOUT_CYCLES-1) begin p2 <= 0; snapshot2 <= 0; end
            // Accept the second nibble only inside the configured frame budget.
            if (pending_player != 0) begin
                if (frame_age < FRAME_CYCLES) frame_age <= frame_age + 1;
                else pending_player <= 0;
            end
            if (rx_valid) begin
                frame_age <= 0;
                pending_player <= 0;
                case (rx_data[7:4])
                    4'h1: begin pending_low <= rx_data[3:0]; pending_player <= 1; end
                    4'h2: if (pending_player == 1 && frame_age < FRAME_CYCLES) begin
                        p1 <= {rx_data[3:0], pending_low}; age1 <= 0; snapshot1 <= 1;
                    end
                    4'h3: begin pending_low <= rx_data[3:0]; pending_player <= 2; end
                    4'h4: if (pending_player == 2 && frame_age < FRAME_CYCLES) begin
                        p2 <= {rx_data[3:0], pending_low}; age2 <= 0; snapshot2 <= 1;
                    end
                    // An edge packet cancels snapshot expiry for player one.
                    default: if (button_mask != 0) begin
                        p1 <= rx_data[7] ? (p1 & ~button_mask) : (p1 | button_mask);
                        snapshot1 <= 0; age1 <= 0;
                    end
                endcase
            end
        end
    end

    // Combinational decode is independent of the register update ordering.
    always @* begin
        case (rx_data[6:0])
            1: button_mask = 8'h10; // Up
            2: button_mask = 8'h20; // Down
            3: button_mask = 8'h40; // Left
            4: button_mask = 8'h80; // Right
            5: button_mask = 8'h01; // A
            6: button_mask = 8'h02; // B
            7: button_mask = 8'h08; // Start
            8: button_mask = 8'h04; // Select
            default: button_mask = 0;
        endcase
    end
endmodule
