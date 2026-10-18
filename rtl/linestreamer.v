`timescale 1ns/1ps

module row_streamer #(
    parameter IMG_W = 28,
    parameter IMG_H = 28
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         start,

    output reg  [11:0]  addr0,
    output reg  [11:0]  addr1,
    output reg  [11:0]  addr2,

    output reg          valid,
    output reg          done
);

    localparam NUM_GROUPS = IMG_H - 2;

    reg         running;
    reg [5:0]   col;          
    reg [5:0]   top_row;      
    reg [11:0]  row_base;     

    always @(posedge clk) begin
        if (rst) begin
            running    <= 1'b0;
            col        <= 6'd0;
            top_row    <= 6'd0;
            row_base   <= 12'd0;
            addr0      <= 12'd0;
            addr1      <= 12'd0;
            addr2      <= 12'd0;
            valid      <= 1'b0;
            done       <= 1'b0;
        end
        else begin
            if (start) begin
                running    <= 1'b1;
                col        <= 6'd0;
                top_row    <= 6'd0;
                row_base   <= 12'd0;
                done       <= 1'b0;
                valid      <= 1'b0;
            end
            else if (running) begin
                if (col == IMG_W - 1) begin
                    col <= 6'd0;
                    if (top_row == NUM_GROUPS - 1) begin
                        running <= 1'b0;
                        done    <= 1'b1;
                    end
                    else begin
                        top_row  <= top_row + 1'b1;
                        row_base <= row_base + IMG_W;
                    end
                end
                else begin
                    col <= col + 1'b1;
                end
            end
            else begin
                done <= 1'b0;
            end

           if (running) begin
    addr0 <= row_base + col;
    addr1 <= row_base + IMG_W + col;
    addr2 <= row_base + 2*IMG_W + col;
    
    valid <= running;
end

            else begin
                addr0 <= 12'd0;
                addr1 <= 12'd0;
                addr2 <= 12'd0;
                valid <= 1'b0;
            end
        end
    end

endmodule