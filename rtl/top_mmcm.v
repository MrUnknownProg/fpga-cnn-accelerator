`timescale 1ns / 1ps

module top_mmcm (
    input  wire       clk,       // 125 MHz board clock
    input  wire       rst,       // active-high button
    input  wire       en,        // start button
    output wire [3:0] digit,
    output wire       fc_done,
    output wire       done
);

    // ---------------- clock generation ----------------
    wire clkfb, clkfb_b, clk_mmcm, clk_fab, locked;

    MMCME2_BASE #(
        .BANDWIDTH        ("OPTIMIZED"),
        .CLKIN1_PERIOD    (8.000),      // 125 MHz
        .DIVCLK_DIVIDE    (1),
        .CLKFBOUT_MULT_F  (8.000),      // VCO = 1000 MHz (legal: 600-1200 MHz, -1 grade)
        .CLKFBOUT_PHASE   (0.000),
        .CLKOUT0_DIVIDE_F (9.000),     // 111 MHz
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE    (0.000),
        .STARTUP_WAIT     ("FALSE")
    ) u_mmcm (
        .CLKIN1   (clk),
        .CLKFBIN  (clkfb_b),
        .CLKFBOUT (clkfb),
        .CLKOUT0  (clk_mmcm),
        .LOCKED   (locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );

    BUFG u_bufg_fb  (.I(clkfb),     .O(clkfb_b));
    BUFG u_bufg_clk (.I(clk_mmcm),  .O(clk_fab));

    // ---------------- reset: async assert, sync release ----------------
    wire arst = rst | ~locked;
    reg [2:0] rst_pipe = 3'b111;
    always @(posedge clk_fab or posedge arst) begin
        if (arst) rst_pipe <= 3'b111;
        else      rst_pipe <= {rst_pipe[1:0], 1'b0};
    end
    wire rst_s = rst_pipe[2];

    // ---------------- start: 2-FF sync + rising-edge pulse ----------------
    reg [1:0] en_pipe = 2'b00;
    reg       en_q    = 1'b0;
    always @(posedge clk_fab) begin
        en_pipe <= {en_pipe[0], en};
        en_q    <= en_pipe[1];
    end
    wire en_pulse = en_pipe[1] & ~en_q;

    // ---------------- CNN core ----------------
    top_deploy u_core (
        .clk     (clk_fab),
        .rst     (rst_s),
        .en      (en_pulse),
        .digit   (digit),
        .fc_done (fc_done),
        .done    (done)
    );

endmodule