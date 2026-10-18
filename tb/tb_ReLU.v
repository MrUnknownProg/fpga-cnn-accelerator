`timescale 1ns/1ps

module tb_ReLU;

reg  signed [19:0] in;
wire signed [19:0] out;

ReLU uut (
    .in(in),
    .out(out)
);

initial begin
    $display("Time\tIN\tOUT");

    in = 20'sd50;   #10;
    $display("%0t\t%d\t%d", $time, in, out);

    in = -20'sd30;  #10;
    $display("%0t\t%d\t%d", $time, in, out);

    in = 20'sd0;    #10;
    $display("%0t\t%d\t%d", $time, in, out);

    in = -20'sd1;   #10;
    $display("%0t\t%d\t%d", $time, in, out);

    $finish;
end

endmodule