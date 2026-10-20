`timescale 1ns/1ps

module tb_top_deploy;

    //------------------------------------------------------------
    // CLOCK / RESET
    //------------------------------------------------------------
    reg clk;
    reg rst;
    reg en;

    //------------------------------------------------------------
    // READ INTERFACE
    //------------------------------------------------------------
    reg  [12:0] rd_addr;
    //reg         rd_en;
    wire signed [19:0] rd_data;

    //------------------------------------------------------------
    // DUT OUTPUTS
    //------------------------------------------------------------
    wire done;
    wire fc_done;
    wire [3:0] digit;

    //------------------------------------------------------------
    // DUT
    //------------------------------------------------------------
    top_deploy dut(

        .clk(clk),
        .rst(rst),
        .en(en),
        .digit(digit),
        .fc_done(fc_done),
        .done(done)
    );

//        conv_only dut (
//            .clk(clk),
//            .rst(rst),
//            .en(en),
//            .done(done)
//            );

    //------------------------------------------------------------
    // CLOCK
    //------------------------------------------------------------
    always #9 clk = ~clk;

    //------------------------------------------------------------
    // FILE HANDLES
    //------------------------------------------------------------
    integer conv_file;
    integer pool_file;
    integer dbg_file;

    //------------------------------------------------------------
    // COUNTERS
    //------------------------------------------------------------
    integer conv_count;
    integer pool_count;

    integer conv_idx;
    integer pool_idx;

    //------------------------------------------------------------
    // DEBUG
    //------------------------------------------------------------
    reg first_seen;
    reg conv_valid_d;
    reg done_d;
    reg fc_done_d;

    //------------------------------------------------------------
    // EXTRA COUNTERS
    //------------------------------------------------------------
    integer conv_valid_count;
    integer actual_conv_count;

    reg signed [19:0] prev_conv_sum;

    //------------------------------------------------------------
    // DEBUG ROW/COL
    //------------------------------------------------------------
    integer dbg_row;
    integer dbg_col;



    //------------------------------------------------------------
    // INITIAL
    //------------------------------------------------------------
    initial
    begin

        clk = 0;
        rst = 1;
        en  = 0;

        conv_count = 0;
        pool_count = 0;

        conv_idx = 0;
        pool_idx = 0;

        conv_valid_count = 0;
        actual_conv_count = 0;

        prev_conv_sum = 0;

        first_seen = 0;
        conv_valid_d = 0;
        done_d = 0;
        fc_done_d = 0;

        //--------------------------------------------------------
        // OPEN FILES
        //--------------------------------------------------------

        conv_file = $fopen("conv_output.txt","w");
        pool_file = $fopen("pool_output.txt","w");
        dbg_file  = $fopen("conv_debug.txt","w");

        if(conv_file == 0)
        begin
            $display("ERROR opening conv_output.txt");
            $finish;
        end

        if(pool_file == 0)
        begin
            $display("ERROR opening pool_output.txt");
            $finish;
        end

        if(dbg_file == 0)
        begin
            $display("ERROR opening conv_debug.txt");
            $finish;
        end

        //--------------------------------------------------------
        // RESET
        //--------------------------------------------------------

        #20;
        rst = 0;

        //--------------------------------------------------------
        // START CNN
        //--------------------------------------------------------

        #50;

        @(posedge clk);
        en = 1;

        @(posedge clk);
        en = 0;

    end

    //------------------------------------------------------------
    // DISPLAY CONV KERNEL
    //------------------------------------------------------------
    initial
    begin

        #1;

        $display("");
        $display("====================================");
        $display("CONVOLUTION KERNEL");
        $display("====================================");

        $display("%4d %4d %4d",
            dut.weight_bram[0],
            dut.weight_bram[1],
            dut.weight_bram[2]);

        $display("%4d %4d %4d",
            dut.weight_bram[3],
            dut.weight_bram[4],
            dut.weight_bram[5]);

        $display("%4d %4d %4d",
            dut.weight_bram[6],
            dut.weight_bram[7],
            dut.weight_bram[8]);

        $display("====================================");
        $display("");

    end    
    
        //------------------------------------------------------------
    // VALID EDGE DETECTION
    //------------------------------------------------------------
    always @(posedge clk)
    begin

        conv_valid_d <= dut.conv_valid;
        done_d       <= done;
        fc_done_d    <= fc_done;

        if(!rst)
        begin


            if(!done_d && done)
            begin
                $display("");
                $display("====================================");
                $display("POOLING COMPLETED");
                $display("TIME = %0t",$time);
                $display("====================================");
                $display("");
            end

            if(!fc_done_d && fc_done)
            begin
                $display("");
                $display("====================================");
                $display("FC COMPLETED");
                $display("TIME = %0t",$time);
                $display("====================================");
                $display("");
            end

        end

    end

    //------------------------------------------------------------
    // CONVOLUTION COUNTERS
    //------------------------------------------------------------
    always @(posedge clk)
    begin

        if(rst)
        begin
            conv_valid_count  <= 0;
            actual_conv_count <= 0;
            prev_conv_sum     <= 0;
        end
        else
        begin

            if(dut.conv_valid)
                conv_valid_count <= conv_valid_count + 1;

            if(dut.conv_valid &&
               (dut.conv_sum !== prev_conv_sum))
                actual_conv_count <= actual_conv_count + 1;

            prev_conv_sum <= dut.conv_sum;

        end

    end

    //------------------------------------------------------------
    // CONVOLUTION DEBUG FILE
    //------------------------------------------------------------
    always @(posedge clk)
    begin

        if(!rst && dut.conv_valid)
        begin

            dbg_row = conv_idx / 26;
            dbg_col = conv_idx % 26;

            $fdisplay(

                dbg_file,

                "%0d | %0d %0d | %0d %0d %0d | %0d %0d %0d %0d %0d %0d %0d %0d %0d | %0d | %0d",

                conv_idx,

                dbg_row,
                dbg_col,

                $signed(dut.row0),
                $signed(dut.row1),
                $signed(dut.row2),

                $signed(dut.o0),
                $signed(dut.o1),
                $signed(dut.o2),
                $signed(dut.o3),
                $signed(dut.o4),
                $signed(dut.o5),
                $signed(dut.o6),
                $signed(dut.o7),
                $signed(dut.o8),

                $signed(dut.conv_sum),

                $signed(dut.relu_out)

            );

        end

    end

    //------------------------------------------------------------
    // STORE CONVOLUTION OUTPUTS
    //------------------------------------------------------------
    always @(posedge clk)
    begin

        if(!rst && dut.conv_valid)
        begin

            conv_count <= conv_count + 1;

            $fdisplay(

                conv_file,

                "%0d : %0d",

                conv_idx,

                $signed(dut.relu_out)

            );

            conv_idx <= conv_idx + 1;

        end

    end

    //------------------------------------------------------------
    // STORE POOL OUTPUTS
    //------------------------------------------------------------

always @(posedge clk)
begin
    if(!rst && dut.pool_valid)
    begin
        pool_count <= pool_count + 1;

        $fdisplay(
            pool_file,
            "%0d : %0d",
            pool_idx,
            $signed(dut.pool_out)
        );

        pool_idx <= pool_idx + 1;
    end
end

    //------------------------------------------------------------
    // OPTIONAL LIVE DEBUG
    //------------------------------------------------------------
//    always @(posedge clk)
//    begin

//        if(!rst && dut.pool_valid)
//        begin

//            $display(
//                "POOL[%0d] = %0d",
//                pool_idx,
//                $signed(dut.pool_out)
//            );

//        end

//    end
    
        //------------------------------------------------------------
    // WAIT FOR COMPLETE CNN INFERENCE
    //------------------------------------------------------------
    initial
    begin

        wait(fc_done);


        #20;

        $display("");
        $display("==================================================");
        $display("              CNN INFERENCE COMPLETE");
        $display("==================================================");

        $display("");
        $display("FC SCORES");
        $display("----------------------------------------------");

        $display("score0 = %0d", dut.score0);
        $display("score1 = %0d", dut.score1);
        $display("score2 = %0d", dut.score2);
        $display("score3 = %0d", dut.score3);
        $display("score4 = %0d", dut.score4);
        $display("score5 = %0d", dut.score5);
        $display("score6 = %0d", dut.score6);
        $display("score7 = %0d", dut.score7);
        $display("score8 = %0d", dut.score8);
        $display("score9 = %0d", dut.score9);

        $display("");
        $display("==================================================");
        $display("Statistics");
        $display("----------------------------------------------");
        $display("Conv Outputs        = %0d", conv_count);
        $display("Pool Outputs        = %0d", pool_count);
        $display("Predicted Digit     = %0d", digit);
        $display("==================================================");
        $display("");

        //--------------------------------------------------------
        // CLOSE FILES
        //--------------------------------------------------------

        if(conv_file != 0)
            $fclose(conv_file);

        if(pool_file != 0)
            $fclose(pool_file);

        if(dbg_file != 0)
            $fclose(dbg_file);

        #100;

        $finish;

    end

    //------------------------------------------------------------
    // TIMEOUT
    //------------------------------------------------------------
   initial
begin
    #10000000;

    $display("");
    $display("==================================================");
    $display("                  TIMEOUT");
    $display("==================================================");
    $display("Simulation Time   = %0t", $time);
    $display("Conv Outputs      = %0d", conv_count);
    $display("Pool Outputs      = %0d", pool_count);
    $display("done (pooling)    = %0b", done);
    $display("pr (pool row)     = %0d", dut.pr);
    $display("pc (pool col)     = %0d", dut.pc);
    $display("fc_done           = %0b", fc_done);
    $display("Predicted Digit   = %0d (only valid if fc_done=1)", digit);
    $display("==================================================");

    if(conv_file != 0)
        $fclose(conv_file);
    if(pool_file != 0)
        $fclose(pool_file);
    if(dbg_file != 0)
        $fclose(dbg_file);

    $finish;
end

endmodule
