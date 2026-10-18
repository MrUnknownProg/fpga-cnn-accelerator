`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.02.2026 10:10:07
// Design Name: 
// Module Name: vedic_2x2
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


module vedic_2x2(
    input  [1:0] a,
    input  [1:0] b,
    output [3:0] p
);
    wire p0, p1, p2, p3;

    assign p0 = a[0] & b[0];
    assign p1 = (a[1] & b[0]) ^ (a[0] & b[1]);
    assign p2 = (a[1] & b[1]) ^ ((a[1] & b[0]) & (a[0] & b[1]));
    assign p3 = (a[1] & b[1]) & ((a[1] & b[0]) & (a[0] & b[1]));

    assign p = {p3, p2, p1, p0};
endmodule
