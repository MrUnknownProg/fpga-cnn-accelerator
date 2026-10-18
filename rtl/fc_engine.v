`timescale 1ns / 1ps

module fc_engine (
    input clk,
    input rst,
    input start,

    output reg done,

    // Feature Memory (synchronous read)
    output [7:0] feature_addr,
    input signed [19:0] feature_data,

    // Weight ROM (synchronous read)
    output [10:0] weight_addr,
    input signed [7:0] weight_data,

    // Bias ROM (small, combinational read is fine)
    output reg [3:0] neuron_idx,
    input signed [15:0] bias_data,

    // FC Scores
    output reg signed [31:0] score0,
    output reg signed [31:0] score1,
    output reg signed [31:0] score2,
    output reg signed [31:0] score3,
    output reg signed [31:0] score4,
    output reg signed [31:0] score5,
    output reg signed [31:0] score6,
    output reg signed [31:0] score7,
    output reg signed [31:0] score8,
    output reg signed [31:0] score9
);

localparam IDLE  = 2'd0;
localparam CALC  = 2'd1;
localparam STORE = 2'd2;
localparam DONE  = 2'd3;

localparam LAST_IDX = 8'd168;   // 13*13 = 169 pooled features

reg [1:0] state;

reg [7:0]  feature_idx;
reg [10:0] w_addr;              // 169*neuron_idx + feature_idx, as a counter
assign feature_addr = feature_idx;
assign weight_addr  = w_addr;

reg signed [31:0] acc;

// stage regs in front of the multiplier (DSP48 A/B registers)
reg signed [19:0] feature_data_p1;
reg signed [7:0]  weight_data_p1;

// valid / last tracking
reg calc_valid;                 // c0: address presented this cycle
reg v1, v2;                     // v1: c1 (mem data valid), v2: c2 (p1 valid -> MAC)
reg l1, l2;                     // "last element of this neuron", same alignment
wire calc_last = calc_valid && (feature_idx == LAST_IDX);

(* use_dsp = "yes" *) wire signed [27:0] product = feature_data_p1 * weight_data_p1;

// registered bias: neuron_idx is stable for >100 cycles before STORE
reg signed [15:0] bias_r;
wire signed [31:0] acc_bias = acc + bias_r;

always @(posedge clk)
begin
    if(rst)
    begin
        state <= IDLE;

        feature_idx <= 0;
        w_addr      <= 0;
        neuron_idx  <= 0;

        acc  <= 0;
        done <= 0;

        feature_data_p1 <= 0;
        weight_data_p1  <= 0;
        bias_r          <= 0;

        calc_valid <= 0;
        v1 <= 0; v2 <= 0;
        l1 <= 0; l2 <= 0;

        score0 <= 0; score1 <= 0; score2 <= 0; score3 <= 0; score4 <= 0;
        score5 <= 0; score6 <= 0; score7 <= 0; score8 <= 0; score9 <= 0;
    end
    else
    begin
        // free-running pipeline
        feature_data_p1 <= feature_data;
        weight_data_p1  <= weight_data;
        bias_r          <= bias_data;

        v1 <= calc_valid;  l1 <= calc_last;
        v2 <= v1;          l2 <= l1;

        case(state)

        //--------------------------------------------------
        IDLE:
        begin
            done <= 0;

            if(start)
            begin
                feature_idx <= 0;
                w_addr      <= 0;
                neuron_idx  <= 0;
                acc         <= 0;
                calc_valid  <= 1;
                state       <= CALC;
            end
            else
                calc_valid <= 0;
        end

        //--------------------------------------------------
        CALC:
        begin
            // consume product of the element issued 2 cycles ago
            if(v2)
                acc <= acc + product;

            // advance the address stream
            if(calc_valid)
            begin
                w_addr <= w_addr + 1'b1;     // runs straight into next neuron's block

                if(feature_idx == LAST_IDX)
                    calc_valid <= 0;
                else
                    feature_idx <= feature_idx + 1'b1;
            end

            // last product of this neuron is being accumulated this cycle
            if(v2 && l2)
                state <= STORE;
        end

        //--------------------------------------------------
        STORE:
        begin
            case(neuron_idx)
                4'd0: score0 <= acc_bias;
                4'd1: score1 <= acc_bias;
                4'd2: score2 <= acc_bias;
                4'd3: score3 <= acc_bias;
                4'd4: score4 <= acc_bias;
                4'd5: score5 <= acc_bias;
                4'd6: score6 <= acc_bias;
                4'd7: score7 <= acc_bias;
                4'd8: score8 <= acc_bias;
                4'd9: score9 <= acc_bias;
                default: ;
            endcase

            if(neuron_idx == 4'd9)
                state <= DONE;
            else
            begin
                neuron_idx  <= neuron_idx + 1'b1;
                feature_idx <= 0;
                acc         <= 0;
                calc_valid  <= 1;       // w_addr already points at next block
                state       <= CALC;
            end
        end

        //--------------------------------------------------
        DONE:
            done <= 1;

        endcase
    end
end

endmodule