`include "define.svh"
module convolution (
	input clk,    // Clock
	input clk_en, // Clock Enable
	input sel_kernal,
	input [3:0] counter,
	input reset,  // Asynchronous reset active high
	input signed [`DATA_BITS-1:0] input_FM, 
	output reg signed [`DATA_BITS-1:0] output_pixel,//[`KERNAL_NUM-1:0]
	output reg conv_done

);
//kernel 0
parameter K0_0 = 20'h0A89E ;
parameter K0_1 = 20'h092D5 ;
parameter K0_2 = 20'h06D43 ;
parameter K0_3 = 20'h01004 ;
parameter K0_4 = 20'hF8F71 ;
parameter K0_5 = 20'hF6E54 ;
parameter K0_6 = 20'hFA6D7 ;
parameter K0_7 = 20'hFC834 ;
parameter K0_8 = 20'hFAC19 ;
parameter Bias_0 = 20'h01310;

//kernel 1
parameter K1_0 = 20'hFDB55 ;
parameter K1_1 = 20'h02992 ;
parameter K1_2 = 20'hFC994 ;
parameter K1_3 = 20'h050FD ;
parameter K1_4 = 20'h02F20 ;
parameter K1_5 = 20'h0202D ;
parameter K1_6 = 20'h03BD7 ;
parameter K1_7 = 20'hFD369 ;
parameter K1_8 = 20'h05E68 ;
parameter Bias_1 = 20'hF7295;

wire clock;
assign clock = clk & clk_en;

reg signed [`DATA_BITS-1:0] kernal_temp;
wire signed [`DATA_BITS-1:0] bias_temp;
assign bias_temp = (sel_kernal)? Bias_1: Bias_0;
always @(counter) begin 
	if(sel_kernal==1'b0)begin
		case(counter)	
			4'd0: kernal_temp = K0_0;
			4'd1: kernal_temp = K0_1;
			4'd2: kernal_temp = K0_2;
			4'd3: kernal_temp = K0_3;
			4'd4: kernal_temp = K0_4;
			4'd5: kernal_temp = K0_5;
			4'd6: kernal_temp = K0_6;
			4'd7: kernal_temp = K0_7;
			4'd8: kernal_temp = K0_8;
			default: kernal_temp = `DATA_BITS'b0;
		endcase
	end
	else begin
		case(counter)	
			4'd0: kernal_temp = K1_0;
			4'd1: kernal_temp = K1_1;
			4'd2: kernal_temp = K1_2;
			4'd3: kernal_temp = K1_3;
			4'd4: kernal_temp = K1_4;
			4'd5: kernal_temp = K1_5;
			4'd6: kernal_temp = K1_6;
			4'd7: kernal_temp = K1_7;
			4'd8: kernal_temp = K1_8;
			default: kernal_temp = `DATA_BITS'b0;
		endcase
	end
end

reg signed [`MUL_DATA_BITS-1:0] mul_temp;
wire signed [`MUL_DATA_BITS-1:0] mul;
assign mul = input_FM*kernal_temp;
always @(posedge clock or posedge reset) begin
	if(reset) begin
		mul_temp <= `MUL_DATA_BITS'b0;
	end else begin
		mul_temp <= input_FM? mul : `MUL_DATA_BITS'b0;
	end
end

reg signed [`MUL_DATA_BITS-1:0] output_temp;
always @(posedge clock or posedge reset) begin
	if(reset) begin
		output_temp <= `MUL_DATA_BITS'b0;
	end else begin
		if(counter == `KERNAL_NUM_2)
			output_temp <= `MUL_DATA_BITS'b0;
		else if (counter == `KERNAL_NUM_1)begin
			output_temp <= output_temp + {bias_temp,16'b0};
		end
		else
			output_temp <= output_temp + mul_temp;
	end
end

reg [`DATA_BITS:0] round_temp;


always@(posedge clock or posedge reset) begin
	if(reset) begin
		round_temp <= `DATA_BITS'b0;
		conv_done <= `FALSE;
	end
	else begin
		if(counter == `KERNAL_NUM_2) begin
			// round_temp <= output_temp[35:15] + output_temp[15];
			round_temp <= output_temp[35:15] + 21'b1;
			conv_done <= `TRUE;
		end
		else begin
			
			round_temp <= `DATA_BITS'b0;
			conv_done <= `FALSE;
		end

	end
	

end

wire test_round;
assign test_round = round_temp[`DATA_BITS];
//ReLU
always@(posedge clk or posedge reset) begin
	if(reset) begin
		output_pixel <= `DATA_BITS'b0;
	end
	else begin
		// if(round_temp == `DATA_BITS'b0) output_pixel <= `DATA_BITS'b0;
		output_pixel <= (round_temp[`DATA_BITS])? `DATA_BITS'b0 : round_temp[`DATA_BITS:1] ;

	end
end

endmodule