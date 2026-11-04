// Modified for RV32 NES integration, 2026-11-01.
`timescale 1ns / 1ps

// AHB-Lite S3 boundary for the existing 512 KiB x 8 NES_MEMORY.
//
// RISC-V loads arrive as aligned 32-bit reads and require four adjacent byte
// cells packed little-endian.  NES accesses remain byte-sized.  One accepted
// AHB transfer owns this adapter until all required byte operations complete;
// HREADYOUT prevents the matrix from changing ownership meanwhile.
module nes_ram_ahb32_adapter #(
    parameter [31:0] S3_BASE = 32'h4000_0000,
    parameter integer BYTE_COUNT = 512*1024
) (
    input  wire        HCLK,
    input  wire        HRESETn,
    input  wire        HSEL,
    input  wire [31:0] HADDR,
    input  wire [31:0] HWDATA,
    input  wire [3:0]  HSTRB,
    input  wire        HWRITE,
    input  wire [1:0]  HTRANS,
    input  wire [2:0]  HSIZE,
    input  wire        HREADY,
    output wire [31:0] HRDATA,
    output wire        HREADYOUT,
    output wire        HRESP
);
    localparam [2:0] IDLE        = 3'd0,
                     DATA_PHASE  = 3'd1,
                     READ_ISSUE  = 3'd2,
                     READ_SAMPLE = 3'd3,
                     WRITE_BYTE  = 3'd4,
                     DONE        = 3'd5,
                     ERROR_1     = 3'd6,
                     ERROR_2     = 3'd7;

    reg [2:0]  state_q;
    reg        write_q;
    reg [18:0] byte_addr_q;
    reg [1:0]  lane_q;
    reg [2:0]  remaining_q;
    reg [31:0] write_data_q;
    reg [31:0] read_data_q;
    reg [3:0]  write_strobe_q;

    wire active = HSEL && HTRANS[1];
    wire accept = active && HREADY;
    wire [31:0] byte_offset = HADDR - S3_BASE;
    wire [2:0] requested_bytes = (HSIZE == 3'b000) ? 3'd1 :
                                 (HSIZE == 3'b001) ? 3'd2 :
                                 (HSIZE == 3'b010) ? 3'd4 : 3'd0;
    wire aligned = (HSIZE == 3'b000) ||
                   ((HSIZE == 3'b001) && (HADDR[0] == 1'b0)) ||
                   ((HSIZE == 3'b010) && (HADDR[1:0] == 2'b00));
    wire in_range = (HADDR >= S3_BASE) &&
                    (byte_offset < BYTE_COUNT) &&
                    ((byte_offset + requested_bytes) <= BYTE_COUNT);
    wire request_legal = (requested_bytes != 0) && aligned && in_range;

    wire [7:0] mem_write_data = write_data_q[8*lane_q +: 8];
    wire mem_write_enable = (state_q == WRITE_BYTE) && write_strobe_q[lane_q];
    wire [7:0] mem_read_data;

    assign HRDATA    = read_data_q;
    assign HREADYOUT = (state_q == IDLE) || (state_q == DONE) ||
                       (state_q == ERROR_2);
    assign HRESP     = (state_q == ERROR_1) || (state_q == ERROR_2);

    NES_MEMORY u_nes_memory (
        .addr(byte_addr_q), .wr_data(mem_write_data),
        .rd_data(mem_read_data), .wr_en(mem_write_enable),
        .clk(HCLK), .rst(!HRESETn)
    );

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state_q          <= IDLE;
            write_q          <= 1'b0;
            byte_addr_q      <= 19'b0;
            lane_q           <= 2'b0;
            remaining_q      <= 3'd1;
            write_data_q     <= 32'b0;
            read_data_q      <= 32'b0;
            write_strobe_q   <= 4'b0;
        end else begin
            case (state_q)
                IDLE, DONE, ERROR_2: begin
                    if (HREADY) begin
                        if (accept) begin
                            write_q        <= HWRITE;
                            byte_addr_q    <= byte_offset[18:0];
                            lane_q         <= HADDR[1:0];
                            remaining_q    <= requested_bytes;
                            read_data_q    <= 32'b0;
                            state_q        <= request_legal ? DATA_PHASE : ERROR_1;
                        end else begin
                            state_q <= IDLE;
                        end
                    end
                end

                // HWDATA and HWSTRB are data-phase signals.  bus data registers
                // both one cycle after HADDR/HTRANS, so they must not be
                // sampled in the address-accept branch above.
                DATA_PHASE: begin
                    write_data_q   <= HWDATA;
                    write_strobe_q <= HSTRB;
                    state_q        <= write_q ? WRITE_BYTE : READ_ISSUE;
                end

                READ_ISSUE: state_q <= READ_SAMPLE;

                READ_SAMPLE: begin
                    read_data_q[8*lane_q +: 8] <= mem_read_data;
                    if (remaining_q == 3'd1) begin
                        state_q <= DONE;
                    end else begin
                        byte_addr_q <= byte_addr_q + 1'b1;
                        lane_q      <= lane_q + 1'b1;
                        remaining_q <= remaining_q - 1'b1;
                        state_q     <= READ_ISSUE;
                    end
                end

                WRITE_BYTE: begin
                    if (remaining_q == 3'd1) begin
                        state_q <= DONE;
                    end else begin
                        byte_addr_q <= byte_addr_q + 1'b1;
                        lane_q      <= lane_q + 1'b1;
                        remaining_q <= remaining_q - 1'b1;
                    end
                end

                ERROR_1: state_q <= ERROR_2;
                default: state_q <= IDLE;
            endcase
        end
    end
endmodule
