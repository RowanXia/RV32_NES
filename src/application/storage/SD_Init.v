// Initialize an SPI card with CMD0, CMD8, CMD55 and ACMD41.
// Transmit commands on sys_clk and capture replies on sys_clk_shift.
// Preserve response-before-timeout priority and the retry state transitions.
module SD_Init
(
	input wire sys_clk ,  
	input wire sys_clk_shift ,  
	input wire sys_rst_n ,  
	input wire miso,  

	output reg cs_n,  
	output reg mosi,  
	output reg init_end  
);

parameter
	CMD0  = {8'h40,8'h00,8'h00,8'h00,8'h00,8'h95},  
	CMD8  = {8'h48,8'h00,8'h00,8'h01,8'haa,8'h87},  
	CMD55 = {8'h77,8'h00,8'h00,8'h00,8'h00,8'h65}, 
												   
	ACMD41= {8'h69,8'h40,8'h00,8'h00,8'h00,8'hff};  

localparam CNT_WAIT_MAX = 8'd100;  
localparam NO_ACK_WAIT_MAX = 8'd100;	 

localparam
	IDLE = 4'b0000,  
	SEND_CMD0 = 4'b0001,  
	CMD0_ACK = 4'b0011,  
	SEND_CMD8 = 4'b0010,  
	CMD8_ACK = 4'b0110,  
	SEND_CMD55 = 4'b0111,  
	CMD55_ACK = 4'b0101,  
	SEND_ACMD41 = 4'b0100,  
	ACMD41_ACK = 4'b1100,  

	INIT_END = 4'b1101;  

reg [7:0]	cnt_wait;	 
reg [3:0]	state;		 
reg [7:0]	cnt_cmd_bit;  
reg			miso_dly;	 
reg			ack_en;		 
reg [39:0]	ack_data;	 
reg [7:0]	cnt_ack_bit;  
reg [7:0]	no_act_wait;	 

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0) begin
		cnt_wait <= 8'd0;
	end else if(cnt_wait >= CNT_WAIT_MAX) begin
		cnt_wait <= CNT_WAIT_MAX;
	end else begin
		cnt_wait <= cnt_wait + 1'b1;
	end
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0) begin
		state <= IDLE;
		`ifdef SD_DBG
		{CMD0_dat, CMD8_dat, CMD55_dat, ACMD41_dat} <= 'b0;
		`endif
	end else begin
		case(state)
		IDLE:
			if(cnt_wait == CNT_WAIT_MAX) begin
				state <= SEND_CMD0;
			end else begin
				state <= state;
			end
			
		SEND_CMD0:
			if(cnt_cmd_bit == 8'd48) begin
				state <= CMD0_ACK;	 
			end else begin
				state <= state;
			end

		CMD0_ACK:
			if(cnt_ack_bit == 8'd48) begin
				if(ack_data[39:32] == 8'h01) begin
					 
					state <= SEND_CMD8;
				end else begin
					state <= SEND_CMD0;
				end
			
			end else if (no_act_wait == NO_ACK_WAIT_MAX) begin
				state <= SEND_CMD0;
			end else begin
				state <= state;
			end
			
		SEND_CMD8:
			if(cnt_cmd_bit == 8'd48) begin
				state <= CMD8_ACK;
			end else begin
				state <= state;
			end
			
		CMD8_ACK:
			if(cnt_ack_bit == 8'd48) begin
				if(ack_data[11:8] == 4'b0001) begin
					state <= SEND_CMD55;
				end else begin
					state <= SEND_CMD8;
				end
			end else if (no_act_wait == NO_ACK_WAIT_MAX) begin
				state <= SEND_CMD8;
			end else begin
				state <= state;
			end
			
		SEND_CMD55:
			if(cnt_cmd_bit == 8'd48)
				state <= CMD55_ACK;
			else
				state <= state;
				
		CMD55_ACK:
			if(cnt_ack_bit == 8'd48) begin
				if (ack_data[39:32] == 8'h01) begin
					state <= SEND_ACMD41;
				end else begin
					state <= SEND_CMD55;
				end
			end else if (no_act_wait == NO_ACK_WAIT_MAX) begin
				state <= SEND_CMD55;
			end else begin
				state <= state;
			end

		SEND_ACMD41:
			if(cnt_cmd_bit == 8'd48)
				state <= ACMD41_ACK;
			else
				state <= state;
		
		ACMD41_ACK:		
			if(cnt_ack_bit == 8'd48) begin
				if(ack_data[39:32] == 8'h00) begin
					state <= INIT_END;
				end else begin
					state <= SEND_CMD55;
				end
			end else if (no_act_wait == NO_ACK_WAIT_MAX) begin
				state <= SEND_CMD55;
			end else begin
				state <= state;
			end
			
		INIT_END:
			state <= state;
			
		default:
			state <= IDLE;
		endcase
	end
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0) begin
		cs_n <= 1'b1;
		mosi <= 1'b1;
		init_end <= 1'b0;
		cnt_cmd_bit <= 8'd0;
	end else begin
		case(state)
		IDLE: begin
			cs_n <= 1'b1;
			mosi <= 1'b1;
			init_end <= 1'b0;
			cnt_cmd_bit <= 8'd0;
		end

		SEND_CMD0:
			if(cnt_cmd_bit == 8'd48) begin
				cnt_cmd_bit <= 8'd0;
			end else begin
				cs_n <= 1'b0;
				mosi <= CMD0[8'd47 - cnt_cmd_bit];	 
				init_end <= 1'b0;
				cnt_cmd_bit <= cnt_cmd_bit + 8'd1;
			end

		CMD0_ACK:
			if(cnt_ack_bit == 8'd47)
				cs_n <= 1'b1;
			else
				cs_n <= 1'b0;

		SEND_CMD8:
			if(cnt_cmd_bit == 8'd48) begin
				cnt_cmd_bit <= 8'd0;
			end else begin
				cs_n <= 1'b0;
				mosi <= CMD8[8'd47 - cnt_cmd_bit];
				init_end <= 1'b0;
				cnt_cmd_bit <= cnt_cmd_bit + 8'd1;
			end

		CMD8_ACK:
			if(cnt_ack_bit == 8'd47)
				cs_n <= 1'b1;
			else
				cs_n <= 1'b0;

		SEND_CMD55:
			if(cnt_cmd_bit == 8'd48) begin
				cnt_cmd_bit <= 8'd0;
			end else begin
				cs_n <= 1'b0;
				mosi <= CMD55[8'd47 - cnt_cmd_bit];
				init_end <= 1'b0;
				cnt_cmd_bit <= cnt_cmd_bit + 8'd1;
			end

		CMD55_ACK:
			if(cnt_ack_bit == 8'd47)
				cs_n <= 1'b1;
			else
				cs_n <= 1'b0;

		SEND_ACMD41:
			if(cnt_cmd_bit == 8'd48)
				cnt_cmd_bit <= 8'd0;
			else begin
				cs_n <= 1'b0;
				mosi <= ACMD41[8'd47 - cnt_cmd_bit];
				init_end <= 1'b0;
				cnt_cmd_bit <= cnt_cmd_bit + 8'd1;
			end

		ACMD41_ACK:
			if(cnt_ack_bit < 8'd47)
				cs_n <= 1'b0;
			else
				cs_n <= 1'b1;

		INIT_END: begin
			cs_n <= 1'b1;
			mosi <= 1'b1;
			init_end <= 1'b1;
		end

		default: begin
			cs_n <= 1'b1;
			mosi <= 1'b1;
		end
		endcase
	end
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0) begin
		no_act_wait <= 8'b0;
	end else if (no_act_wait == NO_ACK_WAIT_MAX) begin
		no_act_wait <= 8'b0;
	end else if ( !ack_en & (state == CMD0_ACK || state == CMD8_ACK
				|| state == CMD55_ACK || state == ACMD41_ACK)) begin
		no_act_wait <= no_act_wait + 1'b1;
	end else begin
		no_act_wait <= 8'b0;
	end
end

always@(posedge sys_clk_shift or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		miso_dly <= 1'b0;
	else
		miso_dly <= miso;
end

always@(posedge sys_clk_shift or negedge sys_rst_n) begin
	if(sys_rst_n == 1'b0)
		ack_en <= 1'b0;
	else if (cnt_ack_bit >= 8'd47)
		ack_en <= 1'b0;
	else if ((miso == 1'b0)&&(miso_dly == 1'b1) && (cnt_ack_bit == 8'd0))

		ack_en <= 1'b1;
	else begin
		ack_en <= ack_en;
	end
end

always @(posedge sys_clk_shift or negedge sys_rst_n) begin
	if (sys_rst_n == 1'b0) begin
		ack_data <= 40'b0;
		cnt_ack_bit <= 8'd0;
	end else if (ack_en == 1'b1) begin
		cnt_ack_bit <= cnt_ack_bit + 8'd1;
		if (cnt_ack_bit < 8'd40) begin
			ack_data <= {ack_data[38:0], miso_dly};
		end else begin
			ack_data <= ack_data;
		end
	end else begin
		cnt_ack_bit <= 8'd0;
	end
end

endmodule
