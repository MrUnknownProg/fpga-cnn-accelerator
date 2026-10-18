`timescale 1ns / 1ps

module ReLU(
    input  signed [19:0] in,
    output signed [19:0] out
);

assign out = (in > 0) ? in : 20'd0;

endmodule

