// ncverilog tb.v huffman.v +define+tb1/2/3+FSDB +access+r +nc64bit
// change synopsys_dc.setup file to .synopsys_dc.setup
//add synthesize.tcl
//change library search path to "/home/nfs_cad/lib/CBDK_IC_Contest_v2.1/SynopsysDC/db/  $search_path" in .setup file
//dc_shell -f synthesize.tcl

module huffman(clk, reset, gray_valid, gray_data, CNT_valid, CNT1, CNT2, CNT3, CNT4, CNT5, CNT6,
    code_valid, HC1, HC2, HC3, HC4, HC5, HC6, M1, M2, M3, M4, M5, M6);

input clk;
input reset;
input gray_valid;
input [7:0] gray_data;
output reg CNT_valid;
output reg [7:0] CNT1, CNT2, CNT3, CNT4, CNT5, CNT6;
output reg code_valid;
output reg [7:0] HC1, HC2, HC3, HC4, HC5, HC6;
output reg [7:0] M1, M2, M3, M4, M5, M6;

integer i; 
reg [2:0] CURRENT, NEXT;
parameter [2:0]  IDLE = 3'd0,
                            COUNT = 3'd1,
                            COUNT_OUT = 3'd2,
                            SORT = 3'd3,
                            COMBINE = 3'd4,
                            SPLIT = 3'd5,
                            OUT = 3'd6;

parameter [7:0] A1 = 8'h1,
                A2 = 8'h2,
                A3 = 8'h3, 
                A4 = 8'h4,
                A5 = 8'h5,
                A6 = 8'h6;
  


/*
Symbol_cnt[8:0]: 
    to store the count number (probability*100) of A1~A6 from [0]~[5], C1~C3 (combine value of C1 to C3 state) from [6]~[8] 
c0_arr[5:0], c1_arr[4:0], c2_arr[3:0], c3_arr[2:0], c4_arr[1:0]: 
    to store the sorted symbols (A1~A6) in each state (C0 to C4 state)
H[5:0]: to record the huffman coding of A1~A6 
M[5:0]: to record the mask of A1~A6 
D[5:0]: to record if each encoding of symbol A1~A6 is done
*/

reg [7:0] Symbol_cnt[8:0]; 

//sorting
wire sort_start;
assign sort_start = (CURRENT == SORT);

reg [3:0] c0_arr[5:0];
reg [2:0] cnt_ind, cnt_turn;
reg sort_done;
reg [2:0] max_ind;

//combination
wire combine_start;
assign combine_start = (CURRENT == COMBINE);

reg [3:0] c1_arr[4:0], c2_arr[3:0], c3_arr[2:0], c4_arr[1:0]; 
reg [1:0] cnt;
wire combine_done;
assign combine_done = (cnt == 2'd3);

//split
reg split_done;
wire split_start;
assign split_start = (CURRENT == SPLIT);
reg [7:0] H[5:0], M[5:0], m;
reg D[5:0]; 
reg [2:0] split_state, next_state, last_state, last_state2;
reg shift_add;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        CNT1 <= 0;
        CNT2 <= 0;
        CNT3 <= 0;
        CNT4 <= 0;
        CNT5 <= 0;
        CNT6 <= 0;
    end
    else if (gray_valid) begin
        case(gray_data)
            A1: CNT1 <= CNT1 + 1;
            A2: CNT2 <= CNT2 + 1;
            A3: CNT3 <= CNT3 + 1;
            A4: CNT4 <= CNT4 + 1;
            A5: CNT5 <= CNT5 + 1;
            A6: CNT6 <= CNT6 + 1;
        endcase
    end
end


always@(posedge clk or posedge reset) begin
    if(reset)  CURRENT <= IDLE;
    else       CURRENT <= NEXT;
end

always@(*)begin
    case(CURRENT)
        IDLE: begin
            if(gray_valid) NEXT = COUNT;
            else NEXT = IDLE;
        end
        COUNT: begin
            if(~gray_valid) NEXT = COUNT_OUT;
            else NEXT = COUNT;
        end
        COUNT_OUT: NEXT = SORT;
        SORT: begin
            if(sort_done) NEXT = COMBINE;
            else NEXT = SORT;
        end
        COMBINE: begin
            if(combine_done) NEXT = SPLIT;
            else NEXT = COMBINE;
        end
        SPLIT: begin
            if(split_done) NEXT = OUT;
            else NEXT = SPLIT;
        end
        OUT: begin
            NEXT = IDLE;
        end
    endcase
end

always@(posedge clk or posedge reset)begin
    if(reset)begin
       
        CNT_valid <= 0;
        code_valid <= 0;
    end
    else begin
        if(CURRENT==COUNT_OUT) begin
            CNT_valid <= 1;
        end
        else if (CURRENT == OUT) begin
            HC1 <= H[0];
            HC2 <= H[1];
            HC3 <= H[2];
            HC4 <= H[3];
            HC5 <= H[4];
            HC6 <= H[5];

            M1 <= M[0];
            M2 <= M[1];
            M3 <= M[2];
            M4 <= M[3];
            M5 <= M[4];
            M6 <= M[5];

            code_valid <= 1;
        end
        else begin
            CNT_valid <= 0;
            code_valid <= 0;
        end
    end
end

//sorting
always@(posedge clk or posedge reset)begin
    if(reset)begin
        c0_arr[0] <= 3'd0;
        c0_arr[1] <= 3'd1;
        c0_arr[2] <= 3'd2;
        c0_arr[3] <= 3'd3;
        c0_arr[4] <= 3'd4;
        c0_arr[5] <= 3'd5;

        cnt_ind <= 3'b1;
        cnt_turn <= 3'b0;
        max_ind <= 3'b0;
        sort_done <= 0;
    end
    else begin
        if(sort_start)begin
            if(cnt_turn == 3'd5) begin
                sort_done <= 1;
            end
            else begin
                if(cnt_ind == 3'd6) begin
                    cnt_ind <= cnt_turn+2;
                    cnt_turn <= cnt_turn + 3'd1;
                    max_ind <= cnt_turn+1;
                    c0_arr[cnt_turn] <= c0_arr[max_ind];
                    c0_arr[max_ind] <= c0_arr[cnt_turn];
                end
                else begin               
                    cnt_ind <= cnt_ind + 3'd1;
                    if(Symbol_cnt[c0_arr[cnt_ind]]== Symbol_cnt[c0_arr[max_ind]] && c0_arr[cnt_ind]<c0_arr[max_ind])
                        max_ind <= cnt_ind;
                    else if(Symbol_cnt[c0_arr[cnt_ind]]>Symbol_cnt[c0_arr[max_ind]])
                        max_ind <= cnt_ind;
                end
            end 
        end
    end
end

reg [2:0] C1_1, C1_2, C2_1, C2_2;
//combination
always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt <= 2'b0;
    end
    else if (combine_start) begin
        cnt <= cnt + 2'b1;
    end
end

parameter C1 = 4'd6,
          C2 = 4'd7,
          C3 = 4'd8,
          C4 = 4'd9;

always@(posedge clk or posedge reset)begin
    if(reset)begin
        c1_arr[0] <= 0;
        c1_arr[1] <= 0;
        c1_arr[2] <= 0;
        c1_arr[3] <= 0;
        c1_arr[4] <= 0;

        c2_arr[0] <= 0;
        c2_arr[1] <= 0;
        c2_arr[2] <= 0;
        c2_arr[3] <= 0;

        c3_arr[0] <= 0;
        c3_arr[1] <= 0;
        c3_arr[2] <= 0;

        c4_arr[0] <= 0;
        c4_arr[1] <= 0;

        C1_1 <= 0;
        C1_2 <= 0;

        C2_1 <= 0;
        C2_2 <= 0;

         for(i = 0; i < 10; i = i + 1)
            Symbol_cnt[i] <= 8'd0;
    end
    else begin
         if(CURRENT==COUNT_OUT) begin
            Symbol_cnt[0] <= CNT1;
            Symbol_cnt[1] <= CNT2;
            Symbol_cnt[2] <= CNT3;
            Symbol_cnt[3] <= CNT4;
            Symbol_cnt[4] <= CNT5;
            Symbol_cnt[5] <= CNT6;
        end
        else begin
            case(cnt)
                2'd0:begin
                    Symbol_cnt[C1] <= Symbol_cnt[c0_arr[4]]+Symbol_cnt[c0_arr[5]];
                    C1_1 <= c0_arr[4];
                    C1_2 <= c0_arr[5];
                    if(Symbol_cnt[c0_arr[4]]+Symbol_cnt[c0_arr[5]] > Symbol_cnt[c0_arr[3]])begin
                        if(Symbol_cnt[c0_arr[4]]+Symbol_cnt[c0_arr[5]] > Symbol_cnt[c0_arr[2]])begin
                            c1_arr[2] <= C1;
                            c1_arr[3] <= c0_arr[2];
                            c1_arr[4] <= c0_arr[3];  
                        end
                        else begin
                            c1_arr[2] <= c0_arr[2];
                            c1_arr[3] <= C1;
                            c1_arr[4] <= c0_arr[3];    
                        end
                        
                    end
                    else begin
                        c1_arr[2] <= c0_arr[2];
                        c1_arr[3] <= c0_arr[3];
                        c1_arr[4] <= C1;
                    end
                    c1_arr[0] <= c0_arr[0];
                    c1_arr[1] <= c0_arr[1];
                end
                2'd1:begin
                    Symbol_cnt[C2] <= Symbol_cnt[c1_arr[3]]+Symbol_cnt[c1_arr[4]];
                    C2_1 <= c1_arr[3];
                    C2_2 <= c1_arr[4];
                    if(Symbol_cnt[c1_arr[3]]+Symbol_cnt[c1_arr[4]] > Symbol_cnt[c1_arr[2]])begin
                        c2_arr[2] <= C2;
                        c2_arr[3] <= c1_arr[2];
                    end
                    else begin
                        c2_arr[2] <= c1_arr[2];
                        c2_arr[3] <= C2;
                    end 
                    c2_arr[0] <= c1_arr[0];
                    c2_arr[1] <= c1_arr[1];
                end
                2'd2:begin
                    Symbol_cnt[C3] <= Symbol_cnt[c2_arr[2]]+Symbol_cnt[c2_arr[3]];
                    if(Symbol_cnt[c2_arr[2]]+Symbol_cnt[c2_arr[3]] > Symbol_cnt[c2_arr[1]])begin
                        c3_arr[1] <= C3;
                        c3_arr[2] <= c2_arr[1];
                    end
                    else begin
                        c3_arr[1] <= c2_arr[1];
                        c3_arr[2] <= C3;
                    end 
                    c3_arr[0] <= c2_arr[0];
                    
                end
                2'd3:begin
                    //Symbol_cnt[C4] = Symbol_cnt[c3_arr[1]]+Symbol_cnt[c3_arr[2]];
                    if(Symbol_cnt[c3_arr[1]]+Symbol_cnt[c3_arr[2]] > Symbol_cnt[c3_arr[0]])begin
                        c4_arr[0] <= C4;
                        c4_arr[1] <= c3_arr[0];
                    end
                    else begin
                        c4_arr[0] <= c3_arr[0];
                        c4_arr[1] <= C4;
                    end 
                end
            endcase
        end
    end
end

//split

parameter [2:0] C4_split = 3'd0,
                C3_split = 3'd1,
                C2_split = 3'd2,
                C1_split = 3'd3,
                C0_split = 3'd4,
                shift = 3'd5,
                wait_state = 3'd6,
                idle = 3'd7;

//shift
parameter [2:0] shift1 = 3'd0,
                shift2 = 3'd1,
                shift3 = 3'd2,
                shift4 = 3'd3,
                shift5 = 3'd4,
                shift6 = 3'd5,
                shift_idle = 6'd6;
reg [2:0] shift_state, shift_next_state;

always@(posedge clk or posedge reset)begin
    if(reset) begin
        split_state <= idle;
    end
    else begin
        split_state <= next_state;
    end
end

always@(*)begin
    case(split_state)
        idle: begin
            if(split_start & ~split_done)
                next_state = C4_split;
            else next_state = idle;
        end
        shift: begin
            // if(last_state != C0_split)
            //     next_state = last_state + 1;
            // else next_state = idle;
            
            if(shift_state == shift6)begin
                if(last_state != C0_split)
                    next_state = last_state + 1;
                else next_state = idle; 
            end
            else next_state = shift;
        end
        wait_state: next_state = shift;
        default: begin
            next_state = wait_state;
        end
    endcase
end

always@(posedge clk or posedge reset)begin
    if(reset) begin
        shift_state <= shift_idle;
    end
    else begin
        shift_state <= shift_next_state;
    end
end

always@(*)begin
    case(shift_state)
        shift_idle: begin
            if(split_state == shift)
                shift_next_state = shift1;
            else
                shift_next_state = shift_state;
        end
        default: shift_next_state = shift_state + 1;

    endcase
end

reg [2:0] mask_v;
reg non_shift;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        m <= 1;
        shift_add <= 0;
        split_done <= 0;
        non_shift <= 0;
        mask_v <= 0;

        for (i=0; i<6; i = i+1) begin
            M[i] <= 0;
            D[i] <= 0; 
            H[i] <= 0; 
        end
       
        
    end
    else if (split_start) begin
        case(split_state)
            C4_split:begin
                if(c4_arr[0]!=C4) begin
                    shift_add <= 1;
                    M[c4_arr[0]] <= m;
                    mask_v <= c4_arr[0];
                end
                else begin
                    shift_add <= 0;
                    M[c4_arr[1]] <= m;
                    mask_v <= c4_arr[1];
                end 
                last_state <= C4_split;
            end
            C3_split:begin
                if(!shift_add)
                    H[mask_v] <= H[mask_v] + 1;

                if(c3_arr[1]!=C3) begin
                    shift_add <= 1;
                    M[c3_arr[1]] <= m;
                    mask_v <= c3_arr[1];
                end
                else begin
                    shift_add <= 0;
                    M[c3_arr[2]] <= m;
                    mask_v <= c3_arr[2];
                end 
                last_state <= C3_split;
            end
            C2_split:begin
                if(!shift_add)
                    H[mask_v] <= H[mask_v] + 1;

                if(c2_arr[2]!=C2) begin
                    shift_add <= 1;
                    M[c2_arr[2]] <= m;
                    mask_v <= c2_arr[2];
                end
                else begin
                    shift_add <= 0;
                    if(c2_arr[3]!=C1)
                        M[c2_arr[3]] <= m;
                    else begin
                        M[C1_1] <= m;
                        M[C1_2] <= m;
                    end
                    mask_v <= c2_arr[3];
                end 
                last_state <= C2_split;
            end
            C1_split:begin
                if(!shift_add)begin
                    if(mask_v == C1)begin
                        H[C1_1] <= H[C1_1] + 1;
                        H[C1_2] <= H[C1_2] + 1;
                    end
                    else
                        H[mask_v] <= H[mask_v] + 1;
                end

                if(c1_arr[4]==C1) begin
                    shift_add <= 1;
                    M[c1_arr[3]] <= m;
                    mask_v <= c1_arr[3];
                end
                else if(c1_arr[3]==C1)begin
                    shift_add <= 0;
                    M[c1_arr[4]] <= m;
                    mask_v <= c1_arr[4];
                end 
                else begin
                    shift_add <= 0;
                    if(c1_arr[2]!=C1)
                        M[c1_arr[2]] <= m;
                    else begin
                        M[C2_1] <= m;
                        M[C2_2] <= m;
                    end
                    mask_v <= c1_arr[2];
                end
                last_state <= C1_split;
            end
            C0_split:begin
                if(!shift_add)begin
                    if(mask_v == C1)begin
                        M[C1_1] <= m;
                        M[C1_2] <= m;
                        if(Symbol_cnt[C2_1]<Symbol_cnt[C2_2])
                            H[C2_1] <= H[C2_1] + 1;
                        else
                            H[C2_2] <= H[C2_2] + 1;
                    end
                    else
                        H[mask_v] <= H[mask_v] + 1;
                end
                    

                if(Symbol_cnt[c0_arr[4]]<Symbol_cnt[c0_arr[5]]) begin
                    shift_add <= 1;
                    if(M[c0_arr[5]]!=0)
                        non_shift <= 1;
                     M[c0_arr[5]] <= m;
                    mask_v <= c0_arr[5];
                end
                else begin
                    shift_add <= 1;
                     if(M[c0_arr[4]]!=0)
                        non_shift <= 1;
                    mask_v <= c0_arr[4];
                    M[c0_arr[4]] <= m;
                end 
                
               
                last_state <= C0_split;
            end
            shift: begin
                if(shift_state == shift6)begin
                    if(mask_v!=C1)begin
                        D[mask_v] <= 1;
                        m <= {m[6:0],1'b1};
                    end
                    else begin
                        if(last_state == C1_split)begin
                            D[C2_1] <= 1;
                            D[C2_2] <= 1;
                        end
                        else
                            m <= {m[6:0],1'b1};
                    end

                    if(mask_v == c0_arr[4])
                        M[c0_arr[5]] <= m;
                    else if (mask_v == c0_arr[5])
                        M[c0_arr[4]] <= m;

                    if(last_state == C0_split)
                        split_done <= 1;
                end
            end
            idle: begin
                if(last_state != idle)begin
                    if(non_shift)begin
                        if(Symbol_cnt[C1_1]>Symbol_cnt[C1_2])
                            H[C1_2] <= H[C1_2] + 1;
                        else
                            H[C1_1] <= H[C1_1] + 1;
                    end

                end
            end
        endcase

        //shift
         case(shift_state)

            shift1: begin
                if(M[0] == 0) begin
                    if(shift_add)
                        H[0] <= {H[0][6:0], 1'b1};
                    else
                        H[0] <= {H[0][6:0], 1'b0};
                end
                else if(D[0]== 0) begin
                    if(mask_v == C1 && last_state == C1_split)
                        H[0] <= H[0];
                    else 
                        H[0] <= {H[0][6:0], 1'b0} ;
                end
            end
            shift2: begin
                if(M[1] == 0) begin
                    if(shift_add)
                        H[1] <= {H[1][6:0], 1'b1};
                    else
                        H[1] <= {H[1][6:0], 1'b0};
                end
                else if(D[1]== 0) begin
                    if(mask_v == C1 && last_state == C1_split)
                        H[1] <= H[1];
                    else 
                        H[1] <= {H[1][6:0], 1'b0};
                end
            end
            shift3: begin
                if(M[2] == 0) begin
                    if(shift_add)
                        H[2] <= {H[2][6:0], 1'b1};
                    else
                        H[2] <= {H[2][6:0], 1'b0};
                end
                else if(D[2]== 0) begin
                    if(mask_v == C1 && last_state == C1_split)
                        H[2] <= H[2];
                    else 
                        H[2] <= {H[2][6:0], 1'b0};
                end
            end
            shift4: begin
                if(M[3] == 0) begin
                    if(shift_add)
                        H[3] <= {H[3][6:0], 1'b1};
                    else
                        H[3] <= {H[3][6:0], 1'b0};
                end
                else if(D[3]== 0) begin
                    if(mask_v == C1 && last_state == C1_split)
                        H[3] <= H[3];
                    else 
                        H[3] <= {H[3][6:0], 1'b0};
                end
            end
            shift5: begin
                if(M[4] == 0) begin
                    if(shift_add)
                        H[4] <= {H[4][6:0], 1'b1};
                    else
                        H[4] <= {H[4][6:0], 1'b0};
                end
                else if(D[4]== 0) begin
                    if(mask_v == C1 && last_state == C1_split)
                        H[4] <= H[4];
                    else 
                        H[4] <= {H[4][6:0], 1'b0};
                end
            end
            shift6: begin
                if(M[5] == 0) begin
                    if(shift_add)
                        H[5] <= {H[5][6:0], 1'b1};
                    else
                        H[5] <= {H[5][6:0], 1'b0};
                end
                else if(D[5]== 0) begin
                    if(mask_v == C1 && last_state == C1_split)
                        H[5] <= H[5];
                    else 
                        H[5] <= {H[5][6:0], 1'b0};
                end
            end

        endcase
    end
end




endmodule

