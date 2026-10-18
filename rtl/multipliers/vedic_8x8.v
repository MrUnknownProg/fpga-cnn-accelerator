`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.02.2026 10:11:53
// Design Name: 
// Module Name: vedic_8x8
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


module vedic_8x8 (
    input  [7:0] a,
    input  [7:0] b,
    output [15:0] p
);
    wire [7:0] p0, p1, p2, p3;
    wire [15:0] sum1, sum2;

    vedic_4x4 v0 (a[3:0], b[3:0], p0);
    vedic_4x4 v1 (a[7:4], b[3:0], p1);
    vedic_4x4 v2 (a[3:0], b[7:4], p2);
    vedic_4x4 v3 (a[7:4], b[7:4], p3);

    assign sum1 = {8'b0, p1} + {8'b0, p2};
    assign sum2 = {p3, 8'b0} + (sum1 << 4);

    assign p = {8'b0, p0} + sum2;
endmodule
