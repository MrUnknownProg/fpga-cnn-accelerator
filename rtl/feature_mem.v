`timescale 1ns / 1ps

module feature_mem (
    input clk,

    input we,
    input [7:0] wr_addr,
    input signed [19:0] din,

    input [7:0] rd_addr,
    output reg signed [19:0] dout
);

    (* ram_style = "block" *) reg signed [19:0] mem [0:168];

    always @(posedge clk)
    begin
        if(we)
            mem[wr_addr] <= din;
        dout <= mem[rd_addr];
    end

endmodule