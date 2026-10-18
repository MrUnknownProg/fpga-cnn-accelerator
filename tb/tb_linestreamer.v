//`timescale 1ns/1ps

//module tb_row_streamer;

//    parameter IMG_W = 28;
//    parameter IMG_H = 28;

//    // Inputs
//    reg clk;
//    reg rst;
//    reg start;

//    // Outputs
//    wire [11:0] addr0;
//    wire [11:0] addr1;
//    wire [11:0] addr2;
//    wire valid;
//    wire done;

//    // DUT
//    row_streamer #(
//        .IMG_W(IMG_W),
//        .IMG_H(IMG_H)
//    ) dut (
//        .clk(clk),
//        .rst(rst),
//        .start(start),
//        .addr0(addr0),
//        .addr1(addr1),
//        .addr2(addr2),
//        .valid(valid),
//        .done(done)
//    );

//    //----------------------------------------------------
//    // Clock Generation (100 MHz)
//    //----------------------------------------------------
//    initial begin
//        clk = 0;
//        forever #5 clk = ~clk;
//    end

//    //----------------------------------------------------
//    // Stimulus
//    //----------------------------------------------------
//    initial begin

//        rst   = 1;
//        start = 0;

//        // Hold reset
//        #20;
//        rst = 0;

//        // Wait a few cycles
//        repeat(2) @(posedge clk);

//        // Pulse start for one clock
//        start = 1;
//        @(posedge clk);
//        start = 0;

//        // Wait until done
//        wait(done);

//        $display("\n====================================");
//        $display("Streaming Complete!");
//        $display("====================================");

//        #20;
//        $finish;
//    end

//    //----------------------------------------------------
//    // Monitor
//    //----------------------------------------------------
//    integer cycle = 0;

//    always @(posedge clk) begin
//        cycle = cycle + 1;

//        if(valid) begin
//            $display("Cycle=%0d  addr0=%3d  addr1=%3d  addr2=%3d",
//                      cycle, addr0, addr1, addr2);
//        end

//        if(done)
//            $display("DONE asserted at cycle %0d", cycle);
//    end

//endmodule

`timescale 1ns/1ps
module tb_row_streamer;
    parameter IMG_W = 28;
    parameter IMG_H = 28;
    reg clk, rst, start;
    wire [11:0] addr0, addr1, addr2;
    wire valid, done;
    integer cycle = 0;
    integer valid_count = 0;
    integer errors = 0;

    row_streamer #(.IMG_W(IMG_W), .IMG_H(IMG_H)) dut (
        .clk(clk), .rst(rst), .start(start),
        .addr0(addr0), .addr1(addr1), .addr2(addr2),
        .valid(valid), .done(done)
    );

    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        rst = 1; start = 0;
        #20;
        rst = 0;
        repeat(2) @(posedge clk); #1;
        start = 1;
        @(posedge clk); #1;
        start = 0;

        while (!done) begin
            @(posedge clk); #1;
            cycle = cycle + 1;
            if (valid) begin
                valid_count = valid_count + 1;
                $display("Cycle=%0d  addr0=%3d  addr1=%3d  addr2=%3d  valid=%0b done=%0b",
                          cycle, addr0, addr1, addr2, valid, done);
            end
        end

        // capture a few cycles past done to see the tail drain to 0
        repeat(4) begin
            @(posedge clk); #1;
            cycle = cycle + 1;
            $display("Cycle=%0d  addr0=%3d  addr1=%3d  addr2=%3d  valid=%0b done=%0b",
                      cycle, addr0, addr1, addr2, valid, done);
        end

        $display("--------------------------------------------------");
        $display("total valid beats: %0d (expected %0d = N + 2 for the 2-cycle drain)",
                  valid_count, IMG_W*(IMG_H-2) + 2);
        $finish;
    end
endmodule