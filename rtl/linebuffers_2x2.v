`timescale 1ns / 1ps

module linebuffer_2x2 #(
    parameter IMG_W = 26
)(
    input             clk,
    input             rst,
    input             en,
    input signed [19:0] pixel_in,   // 20-bit ReLU output

    output reg signed [19:0] row0,       // current row
    output reg signed [19:0] row1        // previous row
);

    reg signed [19:0] lb1 [0:IMG_W-1];

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            row0 <= 20'd0;
            row1 <= 20'd0;

            for (i = 0; i < IMG_W; i = i + 1)
                lb1[i] <= 20'd0;
        end
        else if (en) begin
            // Shift buffer
            for (i = IMG_W-1; i > 0; i = i - 1)
                lb1[i] <= lb1[i-1];

            // Insert newest pixel
            lb1[0] <= pixel_in;

            // Outputs
            row0 <= pixel_in;
            row1 <= lb1[IMG_W-1];
        end
    end

endmodule


