`timescale 1ns / 1ps

module maxpool #(
    parameter IMG_W  = 26,
    parameter DATA_W = 20
)(
    input clk,
    input rst,
    input en,

    input signed [DATA_W-1:0] row0_in,   // current row
    input signed [DATA_W-1:0] row1_in,   // previous row

    output reg signed [DATA_W-1:0] data_out,
    output reg valid_out
);

    reg signed [DATA_W-1:0] row0_prev;
    reg signed [DATA_W-1:0] row1_prev;

    reg [7:0] col, col_d;
    reg [7:0] row, row_d;

    // stage-1 results
    reg signed [DATA_W-1:0] t1, t2;
    reg                     v1;

    // ---------------- stage 1: column-pair max + position tracking -------
    always @(posedge clk) begin
        if (rst) begin
            row0_prev <= 0; row1_prev <= 0;
            row <= 0; col <= 0;
            col_d <= 0; row_d <= 0;
            v1 <= 1'b0;
        end
        else begin
            v1 <= 1'b0;                  // default every cycle

            if (en) begin
                col_d <= col;
                row_d <= row;

                if (row_d > 0 && col_d > 0 && row_d[0] && col_d[0]) begin
                    t1 <= (row0_prev > row0_in) ? row0_prev : row0_in;
                    t2 <= (row1_prev > row1_in) ? row1_prev : row1_in;
                    v1 <= 1'b1;
                end

                row0_prev <= row0_in;
                row1_prev <= row1_in;

                if (col == IMG_W-1) begin
                    col <= 0;
                    row <= row + 1;
                    row0_prev <= 0;
                    row1_prev <= 0;
                end else begin
                    col <= col + 1;
                end
            end
        end
    end

    // ---------------- stage 2: final max (free running, not gated by en) --
    always @(posedge clk) begin
        if (rst) begin
            data_out  <= 0;
            valid_out <= 1'b0;
        end
        else begin
            valid_out <= v1;
            if (v1)
                data_out <= (t1 > t2) ? t1 : t2;
        end
    end

endmodule