// Capture an accepted AHB write address and select its byte lane in the data phase.
// Writes complete without wait states; reads return a fixed identification value.
// The existing HRESP reset assignment and write-enable timing are preserved.
module Graphic_Ram_AHB_Interface(
     
    input  wire                     HCLK,        
    input  wire                     HRESETn,     
    input  wire                     HSEL,        
    input  wire [31:0]              HADDR,       
    input  wire [31:0]              HWDATA,      
    input  wire                     HWRITE,      
    input  wire [1:0]               HTRANS,      
    input  wire [2:0]               HSIZE,       
    input  wire                     HREADY,      
    
    output      [31:0]              HRDATA,      
    output wire                     HREADYOUT,   
    output reg                      HRESP,       

    output      	wr_clk,
    output      	wr_rst,
    output reg    	wr_en,     
    output [5:0]	wr_data,
	output [15:0]	wr_addr
	
);

assign wr_clk = HCLK;
assign wr_rst = !HRESETn;

wire valid_transfer = HSEL & HREADY & (HTRANS == 2'b10 || HTRANS == 2'b11);

wire write_access = valid_transfer & HWRITE;

always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        HRESP = 1'b0;         
    end
end

reg  [31 : 0]    HADDR_delay;         
 
assign wr_addr = HADDR_delay[15 : 0];   
always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        HADDR_delay <= 32'b0;
    end else begin
		if (write_access & HREADY) begin
			 
			HADDR_delay <= HADDR;
		end
	end
end

wire [31:0] lane_data=HWDATA >> (8*HADDR_delay[1:0]);
assign wr_data = lane_data[5:0] & {6{wr_en}};

always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        wr_en <= 1'b0;
    end else if (write_access & HREADYOUT) begin
		wr_en <= 1'b1;
	end else begin
		wr_en <= 1'b0;
	end
end

assign HRDATA = 32'h0d00_0721;

assign HREADYOUT = 1'b1;

endmodule
