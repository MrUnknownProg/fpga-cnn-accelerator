`timescale 1ns / 1ps

module argmax(

    input clk,
    input rst,

    input start,

    input signed [31:0] score0,
    input signed [31:0] score1,
    input signed [31:0] score2,
    input signed [31:0] score3,
    input signed [31:0] score4,
    input signed [31:0] score5,
    input signed [31:0] score6,
    input signed [31:0] score7,
    input signed [31:0] score8,
    input signed [31:0] score9,

    output reg [3:0] digit,
    output reg done

);

// Stage-1 pipeline registers
reg signed [31:0] max0, max1, max2, max3, max4;
reg [3:0]         idx0, idx1, idx2, idx3, idx4;

// Final maximum
reg signed [31:0] max_score;

// Pipeline valid signal
reg stage1_valid;

reg signed [31:0] best_val;   
reg [3:0]         best_idx;

reg signed [31:0] val_ab, val_cd, val_e;   // ADD THIS LINE
reg [3:0]         idx_ab, idx_cd, idx_e;   // ADD THIS LINE
reg               stage2a_valid; 

reg start_d;

wire start_edge = start & ~start_d;

always @(posedge clk)
begin
    if(rst)
    begin
        stage1_valid <= 0;
        done <= 0;
        stage2a_valid <= 0;
        digit <= 0;
        start_d <= 0;
    end
    else
    begin

        done <= 0;
        start_d <= start; 

        //--------------------------------------------------
        // Stage 1
        //--------------------------------------------------
        if(start_edge)
        begin

            if(score0 > score1)
            begin
                max0 <= score0;
                idx0 <= 0;
            end
            else
            begin
                max0 <= score1;
                idx0 <= 1;
            end

            if(score2 > score3)
            begin
                max1 <= score2;
                idx1 <= 2;
            end
            else
            begin
                max1 <= score3;
                idx1 <= 3;
            end

            if(score4 > score5)
            begin
                max2 <= score4;
                idx2 <= 4;
            end
            else
            begin
                max2 <= score5;
                idx2 <= 5;
            end

            if(score6 > score7)
            begin
                max3 <= score6;
                idx3 <= 6;
            end
            else
            begin
                max3 <= score7;
                idx3 <= 7;
            end

            max4 <= score8;
            idx4 <= 8;

            if(score9 > score8)
            begin
                max4 <= score9;
                idx4 <= 9;
            end

            stage1_valid <= 1;
        end

        //--------------------------------------------------
        // Stage 2a: two independent pairwise comparisons
        //--------------------------------------------------
        else if(stage1_valid)
        begin
            if(max0 >= max1) begin 
                val_ab <= max0; 
                idx_ab <= idx0; 
            end
            
            else begin 
                val_ab <= max1; 
                idx_ab <= idx1; 
            end

            if(max2 >= max3) begin 
                val_cd <= max2; 
                idx_cd <= idx2; 
            end
            
            else begin 
                val_cd <= max3; 
                idx_cd <= idx3; 
            end

            val_e <= max4;
            idx_e <= idx4;

            stage2a_valid <= 1;
            stage1_valid  <= 0;
        end
        //--------------------------------------------------
        // Stage 2b: combine the three winners -> final result
        //--------------------------------------------------
        else if(stage2a_valid)
        begin
            if(val_ab >= val_cd) begin 
                best_val = val_ab; 
                best_idx = idx_ab; 
            end
            else begin 
                best_val = val_cd; 
                best_idx = idx_cd; 
            end

            if(val_e > best_val) begin 
                best_val = val_e; 
                best_idx = idx_e; 
            end

            max_score <= best_val;
            digit     <= best_idx;

            done <= 1;
            stage2a_valid <= 0;
        end
    end
end

endmodule