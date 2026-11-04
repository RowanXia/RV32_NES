// Read one CMD17 sector into 128 little-endian 32-bit buffer words.
// Capture serial input on sys_clk_shift and publish buffer writes on sys_clk.
// Detect the data token before counting payload words; retain CRC/end clock cycles.
module SD_Read (
	input wire sys_clk ,  
	input wire sys_clk_shift ,  
	input wire sys_rst_n ,  
	input wire miso ,  
	input wire rd_en,  
	input wire [31:0] rd_addr ,  
	output reg cs_n ,		 
	output reg mosi,			 

	output wire rd_busy ,  
	output reg sd_read_end,	 
	
	output reg rd_data_en ,  
	output reg [31:0] rd_data,  
	output reg [6:0]  sd_rd_addr	 

);

parameter
	IDLE = 3'b000 ,  
	SEND_CMD17 = 3'b001 ,  
	CMD17_ACK = 3'b011 ,  
	RD_DATA = 3'b010 ,  
	RD_END = 3'b110 ;  

parameter DATA_NUM = 12'd128 ;  

wire [47:0] cmd_rd ;  

reg [2:0] state;  
reg [7:0] cnt_cmd_bit ;  
reg ack_en ;  
reg [7:0] ack_data;  
reg [7:0] cnt_ack_bit;  
reg [11:0] cnt_data_num;  
reg [4:0] cnt_data_bit;  
reg [2:0] cnt_end ;  
reg miso_dly ;  
reg [31:0] rd_data_reg ;  
reg [15:0] byte_head ;  
reg byte_head_en;  

assign rd_busy = (state != IDLE) ? 1'b1 : 1'b0;

assign cmd_rd = {8'h51, rd_addr, 8'hff};

always@(posedge sys_clk_shift or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		miso_dly <= 1'b0;
	else
		miso_dly <= miso;
end

always@(posedge sys_clk_shift or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		ack_en <= 1'b0;
	else if(cnt_ack_bit == 8'd15)
		ack_en <= 1'b0;
	else if((state == CMD17_ACK) && (miso == 1'b0)
			&& (miso_dly == 1'b1) && (cnt_ack_bit == 8'd0))
		ack_en <= 1'b1;
	else
		ack_en <= ack_en;
end

always@(posedge sys_clk_shift or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0) begin
		ack_data <= 8'b0;
		cnt_ack_bit <= 8'd0;
	end else if(ack_en == 1'b1) begin
		cnt_ack_bit <= cnt_ack_bit + 8'd1;
		if(cnt_ack_bit < 8'd8)
			ack_data <= {ack_data[6:0],miso_dly};
		else
			ack_data <= ack_data;
	end else
		cnt_ack_bit <= 8'd0;
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0) begin
		state <= IDLE;
		sd_read_end <= 1'b0;
	end else begin
		case(state)
		IDLE: begin
			sd_read_end <= 1'b0;
			if(rd_en == 1'b1)
				state <= SEND_CMD17;
			else
				state <= state;
		end

		SEND_CMD17:
			if(cnt_cmd_bit == 8'd47)
				state <= CMD17_ACK;
			else
				state <= state;

		CMD17_ACK:
			if(cnt_ack_bit == 8'd15) begin
				if(ack_data == 8'h00) begin
					state <= RD_DATA;
				end else begin
					state <= SEND_CMD17;
				end
			end else begin
				state <= state;
			end

		RD_DATA:
			 
			if((cnt_data_num == (DATA_NUM + 1'b1))
				&& (cnt_data_bit == 5'd31))
				state <= RD_END;
			else
				state <= state;

		RD_END:
			if(cnt_end == 3'd7) begin
				state <= IDLE;
				sd_read_end <= 1'b1;
			end else begin
				state <= state;
			end
		default:
			state <= IDLE;
		endcase
	end
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		cs_n <= 1'b1;
	else if(cnt_end == 3'd7)
		cs_n <= 1'b1;
	else if(rd_en == 1'b1)
		cs_n <= 1'b0;
	else
		cs_n <= cs_n;
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		cnt_cmd_bit <= 8'd0;
	else if(state == SEND_CMD17)
		cnt_cmd_bit <= cnt_cmd_bit + 8'd1;
	else
		cnt_cmd_bit <= 8'd0;
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		mosi <= 1'b1;
	else if(state == SEND_CMD17)
		mosi <= cmd_rd[8'd47 - cnt_cmd_bit];
	else
		mosi <= 1'b1;
end

always@(posedge sys_clk_shift or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		byte_head <= 16'b0;
	else if(byte_head_en == 1'b0)
		byte_head <= 16'b0;
	else if(byte_head_en == 1'b1)
		byte_head <= {byte_head[14:0],miso};
	else
		byte_head <= byte_head;
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		byte_head_en <= 1'b0;
	else if(byte_head == 16'hfffe)
		byte_head_en <= 1'b0;
	else if((state == RD_DATA) && (cnt_data_num == 12'd0)
			&& (cnt_data_bit == 4'd0))
		byte_head_en <= 1'b1;
	else
		byte_head_en <= byte_head_en;
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		cnt_data_bit <= 5'd0;
	else if((state == RD_DATA) && (cnt_data_num >= 12'd1))
		cnt_data_bit <= cnt_data_bit + 5'd1;
	else
		cnt_data_bit <= 5'd0;
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		cnt_data_num <= 12'd0;
	else if(state == RD_DATA)
		if((cnt_data_bit == 5'd31) || (byte_head == 16'hfffe))
			cnt_data_num <= cnt_data_num + 12'd1;
		else
			cnt_data_num <= cnt_data_num;
	else
		cnt_data_num <= 12'd0;
end

always@(posedge sys_clk_shift or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		rd_data_reg <= 32'd0;
	else if((state == RD_DATA) && (cnt_data_num >= 12'd1)
			&& (cnt_data_num <= DATA_NUM))
		rd_data_reg <= {rd_data_reg[30:0], miso};
	else
		rd_data_reg <= 32'd0;
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0) begin
		rd_data_en <= 1'b0;
		rd_data <= 32'd0;
		sd_rd_addr <= 7'b111_1111;
	end else if(state == RD_DATA) begin
		if((cnt_data_bit == 5'd31)
			&& (cnt_data_num <= DATA_NUM)) begin
			rd_data_en <= 1'b1;
			 
			rd_data <= {rd_data_reg[7:0], rd_data_reg[15:8],
						rd_data_reg[23:16], rd_data_reg[31:24]};
			sd_rd_addr <= sd_rd_addr + 1'b1;
		end else begin
			rd_data_en <= 1'b0;
			rd_data <= rd_data;
			sd_rd_addr <= sd_rd_addr;
		end
	end else begin
		rd_data_en <= 1'b0;
		rd_data <= 32'd0;
		sd_rd_addr <= 7'b111_1111;
	end
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		cnt_end <= 3'd0;
	else if(state == RD_END)
		cnt_end <= cnt_end + 3'd1;
	else
		cnt_end <= 3'd0;
end

endmodule
