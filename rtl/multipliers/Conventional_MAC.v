`timescale 1ns/1ps
(* use_dsp = "yes" *) 
module mac_dsp_systolic (
    input            clk,
    input            en,
    input            rst,

    input  [7:0]     pixel_in,
    output reg [7:0] pixel_out,

    input  [7:0]     weight_in,
    output reg [7:0] weight_out,

    input  [19:0]    acc_in,
    output reg [19:0] acc_out
);
    (* use_dsp = "yes" *) 
    wire signed [15:0] product;
    reg  signed [19:0] acc_reg;

    // FIX 1: Proper signed multiplication

    assign product = $signed(pixel_in) * $signed(weight_in);

    always @(posedge clk) begin
        if (rst) begin
            acc_reg    <= 0;
            acc_out    <= 0;
            pixel_out  <= 0;
            weight_out <= 0;
        end else begin
            if (en)
                acc_reg <= acc_in + {{4{product[15]}}, product};
            else
                acc_reg <= acc_in;

            // 1-cycle latency pipeline
            acc_out    <= acc_reg;

            // Systolic forwarding (also 1-cycle delayed)
            pixel_out  <= pixel_in;
            weight_out <= weight_in;
        end
    end

endmodule