`include "define.svh"
// `include "convolution.v"
// `include "maxpooling.v"

//if not `include
//ncverilog testfixture.v CONV.v convolution.v maxpooling.v +define+FSDB +access+r +nc64bit
//else
//ncverilog testfixture.v CONV.v +define+FSDB +access+r +nc64bit

`timescale 1ns/10ps

module  CONV(
	input		clk,
	input		reset,
	output		reg busy,	
	input		ready,	
			
	output	reg [`ADDR_BITS-1:0]	iaddr,
	input	[`DATA_BITS-1:0]	idata,	
	
	output	reg 	cwr,
	output	reg [`ADDR_BITS-1:0] 	caddr_wr,
	output	wire [`DATA_BITS-1:0] 	cdata_wr,
	
	output	reg 	crd,
	output	reg [`ADDR_BITS-1:0] 	caddr_rd,
	input	[`DATA_BITS-1:0] 	cdata_rd,
	
	output	reg [`SEL_BITS-1:0] 	csel
	);



reg [3:0] CURRENT, NEXT;

parameter IDLE = 4'd0,
		  L0_K0_READ = 4'd1,
		  L0_K0_WRITE = 4'd2,
		  L0_K1_READ = 4'd3,
		  L0_K1_WRITE = 4'd4,
		  L1_K0_READ = 4'd5,
		  L1_K0_WRITE = 4'd6,
		  L1_K1_READ = 4'd7,
		  L1_K1_WRITE = 4'd8,
		  L2 	= 4'd9;

wire signed [`DATA_BITS-1:0] conv_output;
wire conv_done;
wire signed [`DATA_BITS-1:0] max_output;
wire max_done;

reg L0_enable;
reg L1_enable;

reg [`IND_BITS-1:0] indY, indX;
reg sel_kernal;

wire add_ind;
assign add_ind = (CURRENT == L2)&sel_kernal;

always @(posedge clk or posedge reset) begin
	if(reset) begin
		CURRENT <= IDLE;
	end else begin
		if(busy)
			CURRENT <= NEXT;
	end
end

always@(*)begin
	case (CURRENT)
		IDLE : begin
			NEXT = L0_K0_READ;
		end
		L0_K0_READ : begin
			if (conv_done) 
				NEXT = L0_K0_WRITE;
			else 	
				NEXT = L0_K0_READ;
		end
		L0_K0_WRITE : begin
			if(indX == `IND_BITS'd63 && indY == `IND_BITS'd63)
				NEXT = L0_K1_READ;
			else
				NEXT = L0_K0_READ;
		end
		L0_K1_READ : begin
			if (conv_done) 
				NEXT = L0_K1_WRITE;
			else 	
				NEXT = L0_K1_READ;
		end
		L0_K1_WRITE : begin
			if(indX == `IND_BITS'd63 && indY == `IND_BITS'd63)
				NEXT = L1_K0_READ;
			else
				NEXT = L0_K1_READ;
		end
		L1_K0_READ : begin
			if (max_done) 
				NEXT = L1_K0_WRITE;
			else 	
				NEXT = L1_K0_READ;
		end
		L1_K0_WRITE : begin
			/*if(indX == `IND_BITS'd62 && indY == `IND_BITS'd62)
				NEXT = L1_K1_READ;
			else
				//NEXT = L1_K0_READ;*/
				NEXT = L2;
		end
		L1_K1_READ : begin
			if (max_done) 
				NEXT = L1_K1_WRITE;
			else 	
				NEXT = L1_K1_READ;
		end
		L1_K1_WRITE : begin
				NEXT = L2;
		end
		L2 	  : begin
			if(indX == `IND_BITS'd62 && indY == `IND_BITS'd62 && add_ind)
				//NEXT = L2;
				NEXT = IDLE;
			else begin
				if(~sel_kernal)
					NEXT = L1_K1_READ;
				else
					NEXT = L1_K0_READ;
			end
			
		end
		default : begin
			NEXT = IDLE;
		end
	endcase
end

reg [3:0] kernal_counter;
always @(posedge clk or posedge reset) begin  
	if(reset) begin
		kernal_counter <= 4'b0;
	end else begin
		if(cwr) 
			kernal_counter <= 4'b0;
		else begin
			if(crd) 
				kernal_counter <= kernal_counter + 4'd1;
		end
	end
end




wire [`IND_BITS-1:0] indY_B, indY_A, indX_B, indX_A;
assign indY_B = indY - `IND_BITS'b1;
assign indY_A = indY + `IND_BITS'b1;
assign indX_B = indX - `IND_BITS'b1;
assign indX_A = indX + `IND_BITS'b1;



reg sys_done;

always @(posedge clk or posedge reset) begin 
	if(reset) begin
		indX <= `IND_BITS'b0;
		indY <= `IND_BITS'b0;
		sys_done <= 0;
	end else begin
		if(CURRENT == L0_K0_WRITE || CURRENT == L0_K1_WRITE)begin
			if(indX == `IND_BITS'd63)begin
				indX <= `IND_BITS'b0;
				if(indY == `IND_BITS'd63)
					indY <= `IND_BITS'b0;
				else
					indY <= indY + `IND_BITS'd1;
			end
			else indX <= indX + `IND_BITS'd1;
		end
		else if(add_ind)begin
			if(indX == `IND_BITS'd62)begin
				indX <= `IND_BITS'b0;
				if(indY == `IND_BITS'd62)begin
					indY <= `IND_BITS'b0;
					sys_done <= 1;
				end
				else
					indY <= indY + `IND_BITS'd2;
			end
			else indX <= indX + `IND_BITS'd2;
		end
	end
end
// //convolution
// change
always@(posedge clk or posedge reset) begin
	if(reset) iaddr = `ADDR_BITS'd0;
	else begin
		//if(L0_enable)begin
			case (kernal_counter)
				4'd0: iaddr = {indY_B, indX_B};
				4'd1: iaddr = {indY_B, indX};
				4'd2: iaddr = {indY_B, indX_A};
				4'd3: iaddr = {indY, indX_B};
				4'd4: iaddr = {indY, indX};
				4'd5: iaddr = {indY, indX_A};
				4'd6: iaddr = {indY_A, indX_B};
				4'd7: iaddr = {indY_A, indX};
				4'd8: iaddr = {indY_A, indX_A};
				default : iaddr = `ADDR_BITS'b0;
			endcase
		//end
	end
end
// always@(kernal_counter) begin
// 		//if(L0_enable)begin
// 			case (kernal_counter)
// 				4'd0: iaddr = {indY_B, indX_B};
// 				4'd1: iaddr = {indY_B, indX};
// 				4'd2: iaddr = {indY_B, indX_A};
// 				4'd3: iaddr = {indY, indX_B};
// 				4'd4: iaddr = {indY, indX};
// 				4'd5: iaddr = {indY, indX_A};
// 				4'd6: iaddr = {indY_A, indX_B};
// 				4'd7: iaddr = {indY_A, indX};
// 				4'd8: iaddr = {indY_A, indX_A};
// 				default : iaddr = `ADDR_BITS'b0;
// 			endcase
// 		//end
// end
reg [`DATA_BITS-1:0] conv_input;
reg zero;
//change
always@(posedge clk or posedge reset)begin
	if(reset) zero <= 0;
	else begin
		case (kernal_counter)
			4'd0: zero <= (indX == 0 || indY == 0);
			4'd1: zero <= (indY == 0);
			4'd2: zero <= (indX == `IND_BITS'd63 || indY == 0);
			4'd3: zero <= (indX == 0);
			4'd4: zero <= 0;
			4'd5: zero <= (indX == `IND_BITS'd63);
			4'd6: zero <= (indX == 0 || indY ==`IND_BITS'd63);
			4'd7: zero <= (indY == `IND_BITS'd63);
			4'd8: zero <= (indX == `IND_BITS'd63 || indY == `IND_BITS'd63);
			default : zero <= 0;
		endcase
	end

end
// always@(kernal_counter)begin
// 	case (kernal_counter)
// 		4'd0: zero <= (indX == 0 || indY == 0);
// 		4'd1: zero <= (indY == 0);
// 		4'd2: zero <= (indX == `IND_BITS'd63 || indY == 0);
// 		4'd3: zero <= (indX == 0);
// 		4'd4: zero <= 0;
// 		4'd5: zero <= (indX == `IND_BITS'd63);
// 		4'd6: zero <= (indX == 0 || indY ==`IND_BITS'd63);
// 		4'd7: zero <= (indY == `IND_BITS'd63);
// 		4'd8: zero <= (indX == `IND_BITS'd63 || indY == `IND_BITS'd63);
// 		default : zero <= 0;
// 	endcase
// end

always@(posedge clk or posedge reset)begin
	if(reset)
		conv_input = `DATA_BITS'b0;
	else begin
		/*if(iaddr[`IND_BITS-1:0]==`IND_BITS'b111111 || iaddr[`ADDR_BITS-1:`IND_BITS]==`IND_BITS'b111111 )
			//if indX=62, indY=1, the third place will be 63->111111
			conv_input = `DATA_BITS'b0;
		else
			conv_input = idata;
		*/
		conv_input = zero? `DATA_BITS'b0: idata;
		
		
	end
end

//max-pooling
always@(posedge clk or posedge reset) begin
	if(reset) caddr_rd = `ADDR_BITS'd0;
	else begin
		//if(L1_enable)begin
			case (kernal_counter)
				4'd0: caddr_rd = {indY, indX};
				4'd1: caddr_rd = {indY, indX_A};
				4'd2: caddr_rd = {indY_A, indX};
				4'd3: caddr_rd = {indY_A, indX_A};
				default : caddr_rd = `ADDR_BITS'b0;
			endcase
		//end
	end
end

always @(posedge clk or posedge reset) begin
	if(reset) begin
		busy <= 0;
	end else begin
		if(ready) busy <= 1;
		else if (sys_done) busy <= 0;
	end
end



always@(CURRENT)begin
	case (CURRENT)
		IDLE : begin
			L0_enable = `FALSE;
			L1_enable = `FALSE;
			csel = 3'b000;
			crd = 0;
			cwr = 0;
		end
		L0_K0_READ : begin
			L0_enable = `TRUE;
			L1_enable = `FALSE;
			csel = 3'b001; //no use
			crd = 1;
			cwr = 0;
		end
		L0_K0_WRITE : begin
			L0_enable = `FALSE;
			L1_enable = `FALSE;
			csel = 3'b001;
			crd = 0;
			cwr = 1;
		end
		L0_K1_READ : begin
			L0_enable = `TRUE;
			L1_enable = `FALSE;
			csel = 3'b000; //no use
			crd = 1;
			cwr = 0;
		end
		L0_K1_WRITE : begin
			L0_enable = `FALSE;
			L1_enable = `FALSE;
			csel = 3'b010;
			crd = 0;
			cwr = 1;
		end
		L1_K0_READ : begin
			L0_enable = `FALSE;
			L1_enable = `TRUE;
			csel = 3'b001;//read L0 K0
			crd = 1;
			cwr = 0;
		end
		L1_K0_WRITE : begin
			L0_enable = `FALSE;
			L1_enable = `FALSE;
			csel = 3'b011;
			crd = 0;
			cwr = 1;
			
		end
		L1_K1_READ : begin
			L0_enable = `FALSE;
			L1_enable = `TRUE;
			csel = 3'b010;
			crd = 1;
			cwr = 0;
			
		end
		L1_K1_WRITE : begin
			L0_enable = `FALSE;
			L1_enable = `FALSE;
			csel = 3'b100;
			crd = 0;
			cwr = 1;
			
		end
		default : begin //L2 write the result to flattened layer directly from result of max-mooling
			L0_enable = `FALSE;
			L1_enable = `FALSE;
			csel = 3'b101;
			crd = 0;
			cwr = 1;
		end
	endcase

end

always@(*)begin
	case(CURRENT)
		L0_K0_WRITE: caddr_wr = {indY, indX};
		L0_K1_WRITE: caddr_wr = {indY, indX};
		L1_K0_WRITE: caddr_wr = {indY[`IND_BITS-1:1], indX[`IND_BITS-1:1]};
		L1_K1_WRITE: caddr_wr = {indY[`IND_BITS-1:1], indX[`IND_BITS-1:1]};
		L2: begin
			if(~sel_kernal)
					caddr_wr = {indY[`IND_BITS-1:1], indX};
				else
					caddr_wr = {indY[`IND_BITS-1:1], indX}+`ADDR_BITS'b1;
		end
		default: caddr_wr = `ADDR_BITS'b0;
	endcase
end
assign cdata_wr = (csel>3'b010) ? max_output : conv_output;


always@(posedge clk or posedge reset)begin
	//if(CURRENT == L0_K0_READ || CURRENT == L0_K0_WRITE || CURRENT == L1_K0_READ || CURRENT == L1_K0_WRITE)
	if(reset) sel_kernal = 1'b0;
	else begin
		if(csel[0])
			sel_kernal = 1'b0;
		else sel_kernal = 1'b1;
	end
	
end

reg [`DATA_BITS-1:0] max_input;
always @(posedge clk or posedge reset) begin
	if(reset) begin
		max_input <= 0;
	end else begin
		max_input <= cdata_rd;
	end
end

convolution conv_unit(
	.clk(clk),    // Clock
	.clk_en(L0_enable), // Clock Enable
	.sel_kernal(~csel[0]),
	// .counter(kernal_counter-1),
	.counter(kernal_counter-2),
	.reset(reset),  
	.input_FM(conv_input), 
	.output_pixel(conv_output),
	.conv_done(conv_done)
);


maxpooling max_unit(
	.clk(clk),   
	.clk_en(L1_enable), 
	.reset(reset),  
	.input_FM(max_input),
	.input_counter(kernal_counter-2),
	.max_output_pixel(max_output),
	.max_done(max_done)
);

endmodule