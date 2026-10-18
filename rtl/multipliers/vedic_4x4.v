`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.02.2026 10:10:56
// Design Name: 
// Module Name: vedic_4x4
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module vedic_4x4 (
    input  [3:0] a,
    input  [3:0] b,
    output [7:0] p
);
    wire [3:0] p0, p1, p2, p3;
    wire [7:0] sum1, sum2;

    vedic_2x2 v0 (a[1:0], b[1:0], p0);
    vedic_2x2 v1 (a[3:2], b[1:0], p1);
    vedic_2x2 v2 (a[1:0], b[3:2], p2);
    vedic_2x2 v3 (a[3:2], b[3:2], p3);

    assign sum1 = {2'b00, p1} + {2'b00, p2};
    assign sum2 = {p3, 4'b0000} + (sum1 << 2);

    assign p = {4'b0000, p0} + sum2;
endmodule
