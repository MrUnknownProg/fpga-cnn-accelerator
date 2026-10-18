`timescale 1ns/1ps

module tb_systolic_3x3;

    reg clk;
    reg rst;
    reg en;

    reg signed [7:0] pixel_in0;
    reg signed [7:0] pixel_in1;
    reg signed [7:0] pixel_in2;

    reg signed [7:0] weight_mem [0:8];
    reg signed [7:0] img_mem [0:783];

    wire signed [19:0] out0,out1,out2;
    wire signed [19:0] out3,out4,out5;
    wire signed [19:0] out6,out7,out8;

    integer cycle;

    systolic_3x3 dut (
        .clk(clk),
        .rst(rst),
        .en(en),

        .pixel_in0(pixel_in0),
        .pixel_in1(pixel_in1),
        .pixel_in2(pixel_in2),

        .weight_in0(weight_mem[0]),
        .weight_in1(weight_mem[1]),
        .weight_in2(weight_mem[2]),
        .weight_in3(weight_mem[3]),
        .weight_in4(weight_mem[4]),
        .weight_in5(weight_mem[5]),
        .weight_in6(weight_mem[6]),
        .weight_in7(weight_mem[7]),
        .weight_in8(weight_mem[8]),

        .out0(out0),
        .out1(out1),
        .out2(out2),

        .out3(out3),
        .out4(out4),
        .out5(out5),

        .out6(out6),
        .out7(out7),
        .out8(out8)
    );

    always #5 clk = ~clk;

    initial begin

        clk = 0;
        rst = 1;
        en  = 0;

        cycle = 0;

        pixel_in0 = 0;
        pixel_in1 = 0;
        pixel_in2 = 0;

        // ================= LOAD FILES =================

        $readmemb("weights.mem", weight_mem);
        $readmemb("image0.mem", img_mem);

        // ================= PRINT WEIGHTS =================

        $display("\n=== WEIGHTS ===");

        $display("%4d %4d %4d", weight_mem[0], weight_mem[1], weight_mem[2]);
        $display("%4d %4d %4d", weight_mem[3], weight_mem[4], weight_mem[5]);
        $display("%4d %4d %4d", weight_mem[6], weight_mem[7], weight_mem[8]);

        // ================= PRINT IMPULSE WINDOW =================

        $display("\n=== CENTER WINDOW ===");

        $display("%4d %4d %4d",
                 img_mem[348], img_mem[349], img_mem[350]);

        $display("%4d %4d %4d",
                 img_mem[376], img_mem[377], img_mem[378]);

        $display("%4d %4d %4d",
                 img_mem[404], img_mem[405], img_mem[406]);

        #20;

        rst = 0;
        en  = 1;

        // =====================================
        // Feed Column 0
        // =====================================

        @(negedge clk);

        pixel_in0 = img_mem[348];
        pixel_in1 = img_mem[376];
        pixel_in2 = img_mem[404];

        // =====================================
        // Feed Column 1
        // =====================================

        @(negedge clk);

        pixel_in0 = img_mem[349];
        pixel_in1 = img_mem[377];
        pixel_in2 = img_mem[405];

        // =====================================
        // Feed Column 2
        // =====================================

        @(negedge clk);

        pixel_in0 = img_mem[350];
        pixel_in1 = img_mem[378];
        pixel_in2 = img_mem[406];

        // =====================================
        // Flush
        // =====================================

        repeat(8) begin

            @(negedge clk);

            pixel_in0 = 0;
            pixel_in1 = 0;
            pixel_in2 = 0;

        end

        $finish;

    end

    always @(posedge clk) begin

        cycle = cycle + 1;

        $display(
        "C=%0d | P=[%4d %4d %4d] | o0=%5d o1=%5d o2=%5d | o3=%5d o4=%5d o5=%5d | o6=%5d o7=%5d o8=%5d | SUM=%5d",
        cycle,
        pixel_in0,pixel_in1,pixel_in2,
        dut.o0,dut.o1,dut.o2,
        dut.o3,dut.o4,dut.o5,
        dut.o6,dut.o7,dut.o8,
        out6+out7+out8
        );

    end

endmodule