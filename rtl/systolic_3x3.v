`timescale 1ns/1ps

module systolic_3x3 (
    input             clk,
    input             rst,
    input             en,

    input      signed [7:0]  pixel_in0,
    input      signed [7:0]  pixel_in1,
    input      signed [7:0]  pixel_in2,

    // 3x3 kernel weights
    input      signed [7:0]  weight_in0,
    input      signed [7:0]  weight_in1,
    input      signed [7:0]  weight_in2,
    input      signed [7:0]  weight_in3,
    input      signed [7:0]  weight_in4,
    input      signed [7:0]  weight_in5,
    input      signed [7:0]  weight_in6,
    input      signed [7:0]  weight_in7,
    input      signed [7:0]  weight_in8,

    output reg signed [19:0] out0,out1,out2,
    output reg signed [19:0] out3,out4,out5,
    output reg signed [19:0] out6,out7,out8
);

    // =========================
    // INTERNAL WIRES
    // =========================

    wire signed [19:0] a10,a11,a12;
    wire signed [19:0] a20,a21,a22;

    wire signed [19:0] mac_out6,mac_out7,mac_out8;

    // Pixel propagation
    wire signed [7:0] px0,px1,px2,px3,px4,px5,px6,px7,px8;

    // Weight propagation
    wire signed [7:0] wx0,wx1,wx2,wx3,wx4,wx5,wx6,wx7,wx8;

    // Initial accumulators
    wire signed [19:0] a00 = 20'sd0;
    wire signed [19:0] a01 = 20'sd0;
    wire signed [19:0] a02 = 20'sd0;

    // =========================================================
    // SELECT MAC IMPLEMENTATION (ONLY ONE SHOULD BE ACTIVE)
    // =========================================================

    // ================= SYSTOLIC =================

    wire signed [19:0] o0,o1,o2,o3,o4,o5,o6,o7,o8;

    // =========================
    // OPTION 1: Vedic Multpiers
    // (Uncomment to use, comment others)
    // =========================

    // ================= ROW 1 =================
    
    mac_vedic m00(clk,en,rst,pixel_in0,px0,weight_in0,wx0,20'sd0,o0);
    mac_vedic m01(clk,en,rst,px0,px1,weight_in1,wx1,20'sd0,o1);
    mac_vedic m02(clk,en,rst,px1,px2,weight_in2,wx2,20'sd0,o2);
    
    // ================= ROW 2 =================
    
    mac_vedic m10(clk,en,rst,pixel_in1,px3,weight_in3,wx3,o0,o3);
    mac_vedic m11(clk,en,rst,px3,px4,weight_in4,wx4,o1,o4);
    mac_vedic m12(clk,en,rst,px4,px5,weight_in5,wx5,o2,o5);
    
    // ================= ROW 3 =================
    
    mac_vedic m20(clk,en,rst,pixel_in2,px6,weight_in6,wx6,o3,o6);
    mac_vedic m21(clk,en,rst,px6,px7,weight_in7,wx7,o4,o7);
    mac_vedic m22(clk,en,rst,px7,px8,weight_in8,wx8,o5,o8);

    // =========================
    // OPTION 2: Conventional Multpiers
    // (Uncomment to use, comment others)
    // =========================

//    (* use_dsp = "yes" *) 
//    mac_dsp_systolic m00(clk,en,rst,pixel_in0,px0,weight_in0,wx0,20'sd0,o0);
//    (* use_dsp = "yes" *) 
//    mac_dsp_systolic m01(clk,en,rst,px0,px1,weight_in1,wx1,20'sd0,o1);
//    (* use_dsp = "yes" *) 
//    mac_dsp_systolic m02(clk,en,rst,px1,px2,weight_in2,wx2,20'sd0,o2);
    
//    // ================= ROW 2 =================
//    (* use_dsp = "yes" *) 
//    mac_dsp_systolic m10(clk,en,rst,pixel_in1,px3,weight_in3,wx3,o0,o3);
//    (* use_dsp = "yes" *) 
//    mac_dsp_systolic m11(clk,en,rst,px3,px4,weight_in4,wx4,o1,o4);
//    (* use_dsp = "yes" *) 
//    mac_dsp_systolic m12(clk,en,rst,px4,px5,weight_in5,wx5,o2,o5);
    
//    // ================= ROW 3 =================
//    (* use_dsp = "yes" *) 
//    mac_dsp_systolic m20(clk,en,rst,pixel_in2,px6,weight_in6,wx6,o3,o6);
//    (* use_dsp = "yes" *) 
//    mac_dsp_systolic m21(clk,en,rst,px6,px7,weight_in7,wx7,o4,o7);
//    (* use_dsp = "yes" *) 
//    mac_dsp_systolic m22(clk,en,rst,px7,px8,weight_in8,wx8,o5,o8);


    assign a10 = o0;
    assign a11 = o1;
    assign a12 = o2;

    assign a20 = o3;
    assign a21 = o4;
    assign a22 = o5;

    assign mac_out6 = o6;
    assign mac_out7 = o7;
    assign mac_out8 = o8;

    // =========================
    // OUTPUT REGISTERING
    // =========================

    always @(posedge clk) begin
        if (rst) begin
            out0<=0; out1<=0; out2<=0;
            out3<=0; out4<=0; out5<=0;
            out6<=0; out7<=0; out8<=0;
        end
        else if (en) begin
            // Stage outputs
            out0 <= a10; out1 <= a11; out2 <= a12;
            out3 <= a20; out4 <= a21; out5 <= a22;

            // Final outputs
            out6 <= mac_out6;
            out7 <= mac_out7;
            out8 <= mac_out8;
        end
    end

endmodule