`timescale 1ns/1ps

module tb_fc_engine;

reg clk;
reg rst;
reg start;

wire done;

//--------------------------------------------------
// FEATURE MEM WRITE SIDE
//--------------------------------------------------

reg we;
reg [7:0] feature_wr_addr;
reg signed [19:0] feature_wr_data;

//--------------------------------------------------
// FEATURE MEM READ SIDE
//--------------------------------------------------

wire [7:0] feature_addr;
wire signed [19:0] feature_data;

//--------------------------------------------------
// WEIGHT ROM
//--------------------------------------------------

wire [10:0] weight_addr;
wire signed [7:0] weight_data;

//--------------------------------------------------
// BIAS ROM
//--------------------------------------------------

wire [3:0] neuron_idx;
wire signed [15:0] bias_data;

//--------------------------------------------------
// SCORES
//--------------------------------------------------

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

//--------------------------------------------------
// ARGMAX
//--------------------------------------------------

wire [3:0] digit;
wire argmax_done;

//--------------------------------------------------
// FILE VARIABLES
//--------------------------------------------------

integer fp;
integer idx;
integer dummy;
integer value;
integer ret;
integer i;

//--------------------------------------------------
// FEATURE MEMORY
//--------------------------------------------------

feature_mem FEATURE_MEM (

    .clk(clk),

    .we(we),
    .feature_wr_addr(wr_addr),
    .din(wr_data),

    .feature_rd_addr(feature_addr),
    .dout(feature_data)

);

//--------------------------------------------------
// WEIGHT ROM
//--------------------------------------------------

fc_weight_rom WEIGHT_ROM (

    .addr(weight_addr),
    .weight(weight_data)

);

//--------------------------------------------------
// BIAS ROM
//--------------------------------------------------

fc_bias_rom BIAS_ROM (

    .addr(neuron_idx),
    .bias(bias_data)

);

//--------------------------------------------------
// FC ENGINE
//--------------------------------------------------

fc_engine DUT (

    .clk(clk),
    .rst(rst),
    .start(start),

    .done(done),

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

//--------------------------------------------------
// ARGMAX
//--------------------------------------------------

argmax ARGMAX(

    .clk(clk),
    .rst(rst),

    .start(done),

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
    .done(argmax_done)

);

//--------------------------------------------------
// CLOCK
//--------------------------------------------------

always #5 clk = ~clk;

//--------------------------------------------------
// TEST
//--------------------------------------------------

initial
begin

    clk   = 0;
    rst   = 1;
    start = 0;

    we      = 0;
    feature_wr_addr = 0;
    feature_wr_data = 0;

    //------------------------------------------
    // RESET
    //------------------------------------------

    #50;
    rst = 0;

    //------------------------------------------
    // OPEN FILE
    //------------------------------------------

    fp = $fopen(
"R:/Rutuj/Coding/Verilog/CNN_tp/CNN_tp.sim/sim_1/behav/xsim/pool_output.txt",
"r");

    if(fp == 0)
    begin
        $display("ERROR: pool_output.txt not found");
        $finish;
    end

    //------------------------------------------
    // LOAD FEATURES
    //------------------------------------------

    idx = 0;

    while(!$feof(fp))
    begin

        ret = $fscanf(fp,"%d : %d",dummy,value);

        if(ret == 2)
        begin
            @(posedge clk);

            we      = 1;
            feature_wr_addr = idx;
            feature_wr_data = value;

            idx = idx + 1;
        end

    end

    @(posedge clk);

    we = 0;

    $fclose(fp);

    //------------------------------------------
    // START FC
    //------------------------------------------

    @(posedge clk);

    start = 1;

    @(posedge clk);

    start = 0;

    //------------------------------------------
    // WAIT FOR ARGMAX
    //------------------------------------------

    wait(argmax_done);

    #20;

    //------------------------------------------
    // PRINT RESULTS
    //------------------------------------------

    $display("");
    $display("================================");
    $display("FC SCORES");
    $display("================================");

    $display("score0 = %0d", score0);
    $display("score1 = %0d", score1);
    $display("score2 = %0d", score2);
    $display("score3 = %0d", score3);
    $display("score4 = %0d", score4);
    $display("score5 = %0d", score5);
    $display("score6 = %0d", score6);
    $display("score7 = %0d", score7);
    $display("score8 = %0d", score8);
    $display("score9 = %0d", score9);

    $display("");
    $display("================================");
    $display("PREDICTION");
    $display("================================");
    $display("Predicted Digit = %0d", digit);
    $display("================================");

    #100;
    $finish;

end

endmodule
