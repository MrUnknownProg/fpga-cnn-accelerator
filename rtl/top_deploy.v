`timescale 1ns / 1ps
module top_deploy #(
    parameter IMG_W = 28,
    parameter IMG_H = 28,
    parameter OUT_W = 26
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              en,
    
    output [3:0]             digit,
    output                   fc_done,
    
    output reg               done
);
    localparam TOTAL_WINDOWS = OUT_W * OUT_W;
    localparam POOL_W        = OUT_W / 2;
    localparam TOTAL_POOL    = POOL_W * POOL_W;

    reg signed [7:0]  img_bram    [0:IMG_W*IMG_H-1];
    reg signed [7:0]  weight_bram [0:8];
    
    initial begin
        $readmemb("convolution_weights.mem",weight_bram);
    end
    
    initial begin 
        $readmemb("hand_drawn7.mem", img_bram);
    end

    wire signed [7:0] k0=weight_bram[0], k1=weight_bram[1], k2=weight_bram[2];
    wire signed [7:0] k3=weight_bram[3], k4=weight_bram[4], k5=weight_bram[5];
    wire signed [7:0] k6=weight_bram[6], k7=weight_bram[7], k8=weight_bram[8];

    wire [11:0] rs_addr0, rs_addr1, rs_addr2;
    wire        rs_valid, rs_done;
    
    row_streamer #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) rs_addr_gen (
        .clk(clk),
        .rst(rst),
        .start(en),
        .addr0(rs_addr0),
        .addr1(rs_addr1),
        .addr2(rs_addr2),
        .valid(rs_valid),
        .done(rs_done)
    );

    reg signed [7:0] row0, row1, row2;
    reg              rs_valid_q;

    always @(posedge clk) begin
        if (rst) begin
            row0       <= 8'd0;
            row1       <= 8'd0;
            row2       <= 8'd0;
            rs_valid_q <= 1'b0;
        end else begin
            rs_valid_q <= rs_valid;
            if (rs_valid) begin
                row0 <= img_bram[rs_addr0];
                row1 <= img_bram[rs_addr1];
                row2 <= img_bram[rs_addr2];
            end else begin
                row0 <= 8'd0;
                row1 <= 8'd0;
                row2 <= 8'd0;
            end
        end
    end
        
    wire signed [19:0] o0,o1,o2,o3,o4,o5,o6,o7,o8;
    
    localparam DRAIN_CYCLES = 8;

    reg [3:0] drain_cnt;
    reg       draining;

    always @(posedge clk) begin
        if (rst) begin
            drain_cnt <= 0;
            draining  <= 0;
        end
        else if (rs_valid_q) begin
            drain_cnt <= DRAIN_CYCLES;
            draining  <= 1;
        end
        else if (drain_cnt != 0) begin
            drain_cnt <= drain_cnt - 1;
            draining  <= 1;
        end
        else begin
            draining <= 0;
        end
    end

    wire pipe_en = rs_valid_q || draining;

    reg signed [7:0] row1_s, row2_d1, row2_s;
    always @(posedge clk) begin
        if (rst) begin
            row1_s <= 8'sd0; row2_d1 <= 8'sd0; row2_s <= 8'sd0;
        end else if (pipe_en) begin
            row1_s  <= row1;
            row2_d1 <= row2;
            row2_s  <= row2_d1;
        end
    end

    systolic_3x3 sa (
        .clk(clk), .rst(rst), .en(pipe_en),
        .pixel_in0(row0),
        .pixel_in1(row1_s),
        .pixel_in2(row2_s),
        .weight_in0(k2), .weight_in1(k1), .weight_in2(k0),
        .weight_in3(k5), .weight_in4(k4), .weight_in5(k3),
        .weight_in6(k8), .weight_in7(k7), .weight_in8(k6),
        .out0(o0), .out1(o1), .out2(o2),
        .out3(o3), .out4(o4), .out5(o5),
        .out6(o6), .out7(o7), .out8(o8)
    );

    reg signed [19:0] o6_d1, o6_d2, o6_d3, o6_d4;
    reg signed [19:0] o7_d1, o7_d2;

    always @(posedge clk) begin
        if(rst) begin
            o6_d1 <= 0; o6_d2 <= 0; o6_d3 <= 0; o6_d4 <= 0;
            o7_d1 <= 0; o7_d2 <= 0;
        end
        else if(pipe_en) begin
            o6_d1 <= o6;
            o6_d2 <= o6_d1;
            o6_d3 <= o6_d2;
            o6_d4 <= o6_d3;

            o7_d1 <= o7;
            o7_d2 <= o7_d1;
        end
    end

    wire signed [19:0] conv_sum = o6 + o7 + o8;   
    wire signed [19:0] relu_out;
    
    // Right shift to divide accumulator by 2
    wire signed [19:0] shift = conv_sum >>> 1;

    ReLU relu_inst (
        .in(shift),
        .out(relu_out)
    );

    reg [5:0] row;
    reg [5:0] col;

    always @(posedge clk) begin
        if(rst) begin
            row <= 0;
            col <= 0;
        end
        else if(rs_valid_q) begin
            if(col == IMG_W-1) begin
                col <= 0;
                row <= row + 1;
            end
            else begin
                col <= col + 1;
            end
        end
    end
    
    //=====================================================
    // Delay row/col to match convolution pipeline
    //=====================================================
    
    reg [5:0] row_d1,row_d2,row_d3,row_d4,row_d5;
    reg [5:0] col_d1,col_d2,col_d3,col_d4,col_d5;
    
    always @(posedge clk) begin
        if(rst) begin
            row_d1<=0; row_d2<=0; row_d3<=0; row_d4<=0; row_d5<=0;
            col_d1<=0; col_d2<=0; col_d3<=0; col_d4<=0; col_d5<=0;
        end
        else if(pipe_en) begin
            row_d1<=row;
            row_d2<=row_d1;
            row_d3<=row_d2;
            row_d4<=row_d3;
            row_d5<=row_d4;
    
            col_d1<=col;
            col_d2<=col_d1;
            col_d3<=col_d2;
            col_d4<=col_d3;
            col_d5<=col_d4;
        end
    end
    
    wire conv_window_valid;
    wire conv_valid;
    
    assign conv_window_valid = pipe_en && (col_d4 >= 2);
    
    reg [9:0] conv_counter;
    
    always @(posedge clk) begin
        if (rst)
            conv_counter <= 0;
        else if (conv_window_valid && (conv_counter < TOTAL_WINDOWS))
            conv_counter <= conv_counter + 1;
    end
    
    assign conv_valid = conv_window_valid && (conv_counter < TOTAL_WINDOWS);
        
    //=====================================================
    // Pooling drain: give maxpool one extra enabled cycle
    // to catch up to its own 1-cycle-delayed col_d/row_d
    //=====================================================
    wire conv_finished_this_cycle = conv_window_valid && (conv_counter == TOTAL_WINDOWS - 1);
    
    reg pool_drain_extra;
    always @(posedge clk) begin
        if (rst)
            pool_drain_extra <= 0;
        else
            pool_drain_extra <= conv_finished_this_cycle;
    end
    
    wire pool_en = conv_valid || pool_drain_extra;
    
    
    wire [19:0] row0_out, row1_out;
    
    linebuffer_2x2 #(
        .IMG_W(OUT_W)  
    ) lb_2 ( 
        .clk(clk),
        .rst(rst),
        .en(pool_en),
        .pixel_in(relu_out),
        .row0(row0_out),
        .row1(row1_out)
    );

    wire signed [19:0] pool_out;
    wire pool_valid;
    
    maxpool #(
        .IMG_W(OUT_W),
        .DATA_W(20)
    ) pool_inst (
        .clk(clk),
        .rst(rst),
        .en(pool_en),
        .row0_in(row0_out),
        .row1_in(row1_out),
        .data_out(pool_out),
        .valid_out(pool_valid)
    );

    reg [4:0] pr, pc;

    wire feature_we_int;
    wire [7:0] feature_wr_addr_int;
    wire signed [19:0] feature_din_int;

    // Only allow writes until pooling has completed
    assign feature_we_int = pool_valid && !done;

    // Write address is just a counter 0..168 (replaces 13*pr + pc adders)
    reg [7:0] wr_addr_cnt;
    always @(posedge clk) begin
        if (rst)             wr_addr_cnt <= 0;
        else if (pool_valid) wr_addr_cnt <= wr_addr_cnt + 1'b1;
    end
    assign feature_wr_addr_int = wr_addr_cnt;

    // Data written into feature memory
    assign feature_din_int = pool_out;
    
    wire [7:0] feature_addr;
    wire signed [19:0] feature_data;

    always @(posedge clk) begin
        if (rst) begin
            pr <= 0;
            pc <= 0;
            done <= 0;
        end 
        else if (pool_valid) begin

            if (pc == POOL_W - 1) begin
                pc <= 0;
                pr <= pr + 1;
            end else begin
                pc <= pc + 1;
            end

            if (pr == POOL_W-1 && pc == POOL_W-1)
                done <= 1;
        end
    end

    //--------------------------------------------------------
    // Feature Memory <-> FC Engine
    //--------------------------------------------------------
   
   feature_mem u_feature_mem(

    .clk(clk),

    .we(feature_we_int),
    .wr_addr(feature_wr_addr_int),
    .din(feature_din_int),

    .rd_addr(feature_addr),
    .dout(feature_data)

    );
    
    //--------------------------------------------------------
    // FC Interface Signals
   //--------------------------------------------------------

    wire [10:0]        weight_addr;
    reg  signed [7:0]  weight_data;
    
    wire [3:0]         neuron_idx;
    wire signed [15:0] bias_data;

    //--------------------------------------------------------
    // Weight ROM <-> FC Engine
    //--------------------------------------------------------
    (* rom_style = "block" *) reg signed [7:0] fc_weights [0:1689];

    initial
        $readmemb("fc_weights.mem",fc_weights);
   
    always @(posedge clk) weight_data <= fc_weights[weight_addr];
    
    //--------------------------------------------------------
    // Bias ROM <-> FC Engine
    //--------------------------------------------------------
    (* rom_style = "block" *) reg signed [15:0] fc_bias [0:9];

    initial
        $readmemb("fc_bias.mem",fc_bias);
    
    assign bias_data = fc_bias[neuron_idx];

    //--------------------------------------------------------
    // FC Engine <-> Argmax
    //--------------------------------------------------------
    wire engine_done;

    wire signed [31:0] score0;
    wire signed [31:0] score1;
    wire signed [31:0] score2;
    wire signed [31:0] score3;
    wire signed [31:0] score4;
    wire signed [31:0] score5;
    wire signed [31:0] score6;
    wire signed [31:0] score7;
    wire signed [31:0] score8;
    wire signed [31:0] score9;

    fc_engine u_fc_engine(

        .clk(clk),
        .rst(rst),
        .start(done),

        .done(engine_done),

        .feature_addr(feature_addr),
        .feature_data(feature_data),

        .weight_addr(weight_addr),
        .weight_data(weight_data),

        .neuron_idx(neuron_idx),
        .bias_data(bias_data),

        .score0(score0),
        .score1(score1),
        .score2(score2),
        .score3(score3),
        .score4(score4),
        .score5(score5),
        .score6(score6),
        .score7(score7),
        .score8(score8),
        .score9(score9)

    );

    //--------------------------------------------------------
    // Argmax
    //--------------------------------------------------------
    argmax u_argmax(

        .clk(clk),
        .rst(rst),

        .start(engine_done),

        .score0(score0),
        .score1(score1),
        .score2(score2),
        .score3(score3),
        .score4(score4),
        .score5(score5),
        .score6(score6),
        .score7(score7),
        .score8(score8),
        .score9(score9),

        .digit(digit),
        .done(fc_done)

    );


endmodule
