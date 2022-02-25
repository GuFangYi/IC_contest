`include "define.svh"
module maxpooling (
	input clk,    // Clock
	input clk_en, // Clock Enable
	input reset,  // Asynchronous reset active high
	input signed [`DATA_BITS-1:0] input_FM,
	input [3:0] input_counter,
	output reg signed [`DATA_BITS-1:0] max_output_pixel,
	output reg max_done
);

reg signed [`DATA_BITS-1:0] input_buffer;

always @(posedge clk or posedge reset) begin 
	if(reset) begin
		max_done <= `FALSE;
		max_output_pixel = `DATA_BITS'b0;
	end else if(clk_en) begin
		if(input_counter == `MAX_NUM_1)begin
			max_done <= `TRUE;
			max_output_pixel = input_buffer;
		end
		else begin
			max_done <= `FALSE;
			//max_output_pixel = `DATA_BITS'b0;
		end
	end
end

always @(posedge clk or posedge reset) begin 
	if(reset) begin
		input_buffer <= `DATA_BITS'b0;
	end else if(clk_en) begin
		if(input_counter == `MAX_NUM_1)
			input_buffer <= `DATA_BITS'b0;
		else if(input_counter < `MAX_NUM_1)begin
			if(input_FM>input_buffer)
				input_buffer <= input_FM;
		end
	end
end



endmodule