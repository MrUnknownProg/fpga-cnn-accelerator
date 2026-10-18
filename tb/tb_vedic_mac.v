`timescale 1ns/1ps

module tb_mac_vedic;

    reg clk, en;
    reg signed [7:0] pixel, weight;
    reg signed [19:0] acc_in;
    wire signed [19:0] acc_out;

    integer i, j;
    integer pass_count = 0;
    integer fail_count = 0;

    reg signed [19:0] expected;

    mac_vedic dut (
        .clk(clk),
        .en(en),
        .pixel_in(pixel),
        .pixel_out(),
        .weight_in(weight),
        .weight_out(),
        .acc_in(acc_in),
        .acc_out(acc_out)
    );

    always #5 clk = ~clk;

    /////////////////////////////////////////////////////////

    task run_test;
    begin
        @(posedge clk); #1;

        expected = acc_in + ($signed(pixel) * $signed(weight));

        if (acc_out !== expected) begin
            fail_count = fail_count + 1;
            $display("FAIL | P=%4d W=%4d | ACC_IN=%6d | GOT=%6d EXP=%6d",
                     pixel, weight, acc_in, acc_out, expected);
        end else begin
            pass_count = pass_count + 1;
        end
    end
    endtask

    /////////////////////////////////////////////////////////

    initial begin
        clk = 0;
        en  = 1;
        acc_in = 0;

        $display("===== EXHAUSTIVE VEDIC MAC TEST =====");

        // Exhaustive test (all 8-bit signed values)
        for (i = -128; i < 128; i = i + 1) begin
            for (j = -128; j < 128; j = j + 1) begin

                pixel  = i;
                weight = j;

                // Keep accumulation chain (true MAC behavior)
                run_test();

                acc_in = acc_out;   // accumulate forward
            end
        end

        // Final report
        #10;
        $display("=================================");
        $display("TOTAL PASS = %0d", pass_count);
        $display("TOTAL FAIL = %0d", fail_count);
        $display("=================================");

        $finish;
    end

    /////////////////////////////////////////////////////////

    initial begin
        #5000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
