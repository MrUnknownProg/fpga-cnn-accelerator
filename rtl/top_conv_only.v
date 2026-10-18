`timescale 1ns/1ps

module conv_only #(
    parameter IMG_W = 28,
    parameter IMG_H = 28,
    parameter OUT_W = 26
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              en,

//    input  wire              rd_en,
    
    output reg               done
);

    wire signed [12:0]       rd_addr;
    reg signed [19:0] rd_data;

    localparam TOTAL_WINDOWS = OUT_W * OUT_W;
    localparam POOL_W        = OUT_W / 2;
    localparam TOTAL_POOL    = POOL_W * POOL_W;

    reg signed [7:0]  img_bram    [0:IMG_W*IMG_H-1];
    reg signed [7:0]  weight_bram [0:8];
    reg signed [19:0] pool_bram   [0:TOTAL_POOL-1];
    
    initial begin
    $readmemb("weights.mem", weight_bram);
    end
    
    initial begin 
        $readmemb("hand_drawn7.mem", img_bram);
    end

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < TOTAL_POOL; i = i + 1)
                pool_bram[i] <= 0;
        end
    end

    wire signed [7:0] k0=weight_bram[0], k1=weight_bram[1], k2=weight_bram[2];
    wire signed [7:0] k3=weight_bram[3], k4=weight_bram[4], k5=weight_bram[5];
    wire signed [7:0] k6=weight_bram[6], k7=weight_bram[7], k8=weight_bram[8];

    wire [11:0] rs_addr0, rs_addr1, rs_addr2;
    wire        rs_valid, rs_done;
    
    row_streamer #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) rs_addr_gen (
        .clk(clk),
        .rst(rst),
        .start(en),
        .addr0(rs_addr0),
        .addr1(rs_addr1),
        .addr2(rs_addr2),
        .valid(rs_valid),
        .done(rs_done)
    );

    reg signed [7:0] row0, row1, row2;
    reg              rs_valid_q;

    always @(posedge clk) begin
        if (rst) begin
            row0       <= 8'd0;
            row1       <= 8'd0;
            row2       <= 8'd0;
            rs_valid_q <= 1'b0;
        end else begin
            rs_valid_q <= rs_valid;
            if (rs_valid) begin
                row0 <= img_bram[rs_addr0];
                row1 <= img_bram[rs_addr1];
                row2 <= img_bram[rs_addr2];
            end else begin
                row0 <= 8'd0;
                row1 <= 8'd0;
                row2 <= 8'd0;
            end
        end
    end
        
    wire signed [19:0] o0,o1,o2,o3,o4,o5,o6,o7,o8;

    systolic_3x3 sa (
        .clk(clk), .rst(rst), .en(rs_valid_q),
        .pixel_in0(row0),    
        .pixel_in1(row1), 
        .pixel_in2(row2), 
        .weight_in0(k0), .weight_in1(k1), .weight_in2(k2),
        .weight_in3(k3), .weight_in4(k4), .weight_in5(k5),
        .weight_in6(k6), .weight_in7(k7), .weight_in8(k8),
        .out0(o0), .out1(o1), .out2(o2),
        .out3(o3), .out4(o4), .out5(o5),
        .out6(o6), .out7(o7), .out8(o8)
    );

    reg signed [19:0] o6_d1, o6_d2, o6_d3, o6_d4;
    reg signed [19:0] o7_d1, o7_d2;

    always @(posedge clk) begin
        if(rst) begin
            o6_d1 <= 0; o6_d2 <= 0; o6_d3 <= 0; o6_d4 <= 0;
            o7_d1 <= 0; o7_d2 <= 0;
        end
        else if(rs_valid_q) begin
            o6_d1 <= o6;
            o6_d2 <= o6_d1;
            o6_d3 <= o6_d2;
            o6_d4 <= o6_d3;

            o7_d1 <= o7;
            o7_d2 <= o7_d1;
        end
    end

    wire signed [19:0] conv_sum = o6_d3 + o7_d2 + o8;
    wire signed [19:0] relu_out;

    ReLU relu_inst (
        .in(conv_sum),
        .out(relu_out)
    );

    reg [5:0] row;
    reg [5:0] col;

    always @(posedge clk) begin
        if(rst) begin
            row <= 0;
            col <= 0;
        end
        else if(rs_valid_q) begin
            if(col == IMG_W-1) begin
                col <= 0;
                row <= row + 1;
            end
            else begin
                col <= col + 1;
            end
        end
    end

    wire window_valid =(col >= 2);

    reg [4:0] valid_pipe;
    always @(posedge clk) begin
        if(rst)
            valid_pipe <= 5'b0;
        else if(rs_valid_q)
            valid_pipe <= {valid_pipe[3:0], window_valid};
    end

    wire raw_conv_valid = valid_pipe[4];

    reg [9:0] conv_counter;
    always @(posedge clk) begin
        if (rst) begin
            conv_counter <= 0;
        end
        else if (rs_valid_q && raw_conv_valid && (conv_counter < TOTAL_WINDOWS)) begin
            conv_counter <= conv_counter + 1;
        end
    end

    wire conv_valid = raw_conv_valid && (conv_counter < TOTAL_WINDOWS);
    
    wire [19:0] row0_out, row1_out;
    
    linebuffer_2x2 #(
        .IMG_W(OUT_W)  
    ) lb_2 ( 
        .clk(clk),
        .rst(rst),
        .en(conv_valid),
        .pixel_in(relu_out),
        .row0(row0_out),
        .row1(row1_out)
    );

    wire signed [19:0] pool_out;
    wire pool_valid;
    
    maxpool #(
        .IMG_W(OUT_W),
        .DATA_W(20)
    ) pool_inst (
        .clk(clk),
        .rst(rst),
        .en(conv_valid),
        .row0_in(row0_out),
        .row1_in(row1_out),
        .data_out(pool_out),
        .valid_out(pool_valid)
    );

    reg [4:0] pr, pc;

    always @(posedge clk) begin
        if (rst) begin
            pr <= 0;
            pc <= 0;
            done <= 0;
        end 
        else if (pool_valid) begin
            pool_bram[pr * POOL_W + pc] <= pool_out;

            if (pc == POOL_W - 1) begin
                pc <= 0;
                pr <= pr + 1;
            end else begin
                pc <= pc + 1;
            end

            if (pr == POOL_W-1 && pc == POOL_W-1)
                done <= 1;
        end
    end

//    always @(posedge clk) begin
//        if (rd_en)
//            rd_data <= pool_bram[rd_addr];
//    end

endmodule


















// `timescale 1ns/1ps
// module top_3x3 #(
//     parameter IMG_W = 28,
//     parameter OUT_W = 26
// )(
//     input clk,
//     input rst,
//     input en,

//     input  [12:0] rd_addr,
//     input         rd_en,
//     output reg signed [19:0] rd_data,

//     output reg done
// );

//     localparam TOTAL_WINDOWS = OUT_W * OUT_W;
//     localparam POOL_W = OUT_W / 2;
//     localparam TOTAL_POOL = POOL_W * POOL_W;

//     // ================= MEMORY =================
//     reg signed [7:0]  img_bram    [0:IMG_W*IMG_W-1];
//     reg signed [7:0]  weight_bram [0:8];
//     reg signed [19:0] pool_bram   [0:TOTAL_POOL-1];

//     // ================= INIT MEMORY =================
//     integer i;
//     always @(posedge clk) begin
//         if (rst) begin
//             for (i = 0; i < TOTAL_POOL; i = i + 1)
//                 pool_bram[i] <= 0;
//         end
//     end

//     // ================= IMAGE STREAM =================
//     reg [12:0] img_addr;
//     wire signed [7:0] pixel_in = img_bram[img_addr];

//     always @(posedge clk) begin
//         if (rst) img_addr <= 0;
//         else if (en) img_addr <= img_addr + 1;
//     end

//     // ================= WEIGHTS =================
//     wire signed [7:0] k0=weight_bram[0], k1=weight_bram[1], k2=weight_bram[2];
//     wire signed [7:0] k3=weight_bram[3], k4=weight_bram[4], k5=weight_bram[5];
//     wire signed [7:0] k6=weight_bram[6], k7=weight_bram[7], k8=weight_bram[8];


//     // ================= LINE BUFFER =================
//     wire [7:0] row0,row1,row2;

//     linebuff_3x3 #(
//         .IMG_W(28)
//     ) lb (
//         .clk(clk),
//         .rst(rst),
//         .en(en),
//         .pixel_in(pixel_in),
    
//         .row0(row0),
//         .row1(row1),
//         .row2(row2)
//     );
    
// //   // ================= SLIDING WINDOW ================= 
// //    wire [71:0] win_flat;
// //    wire valid_window;
    
// //    window_gen u_window_gen (
// //    .clk       (clk),
// //    .rst       (rst),
// //    .valid_in  (en),

// //    .row0_pix  (row2),
// //    .row1_pix  (row1),
// //    .row2_pix  (row0),

// //    .w00       (w00),
// //    .w01       (w01),
// //    .w02       (w02),

// //    .w10       (w10),
// //    .w11       (w11),
// //    .w12       (w12),

// //    .w20       (w20),
// //    .w21       (w21),
// //    .w22       (w22),

// //    .valid_out (win_valid)
// //);

// //    // ================= PIXELS =================
// //    wire signed [7:0] p0 = win_flat[6*8 +: 8];
// //    wire signed [7:0] p1 = win_flat[7*8 +: 8];
// //    wire signed [7:0] p2 = win_flat[8*8 +: 8];

//     // ================= SYSTOLIC =================
//     wire signed [19:0] o0,o1,o2,o3,o4,o5,o6,o7,o8;

//     reg signed [7:0] row1_d1;
//     reg signed [7:0] row2_d1, row2_d2;

//     always @(posedge clk) begin
//         if (rst) begin
//             row1_d1 <= 0;
//             row2_d1 <= 0;
//             row2_d2 <= 0;
//         end else if (en) begin
//             row1_d1 <= row1;
//             row2_d1 <= row2;
//             row2_d2 <= row2_d1;
//         end
//     end

//     systolic_3x3 sa (
//         .clk(clk), .rst(rst), .en(en),
//         .pixel_in0(row0),    
//         .pixel_in1(row1), 
//         .pixel_in2(row2), 
//         .weight_in0(k0), .weight_in1(k1), .weight_in2(k2),
//         .weight_in3(k3), .weight_in4(k4), .weight_in5(k5),
//         .weight_in6(k6), .weight_in7(k7), .weight_in8(k8),
//         .out0(o0), .out1(o1), .out2(o2),
//         .out3(o3), .out4(o4), .out5(o5),
//         .out6(o6), .out7(o7), .out8(o8)
//     );


// //    systolic_3x3 sa (
// //        .clk(clk), .rst(rst), .en(en),
// //        .pixel_in0(row0), .pixel_in1(row1), .pixel_in2(row2),
// //        .weight_in0(k0), .weight_in1(k1), .weight_in2(k2),
// //        .weight_in3(k3), .weight_in4(k4), .weight_in5(k5),
// //        .weight_in6(k6), .weight_in7(k7), .weight_in8(k8),
// //        .out0(o0),.out1(o1),.out2(o2),
// //        .out3(o3),.out4(o4),.out5(o5),
// //        .out6(o6),.out7(o7),.out8(o8)
// //    );


//     // ================= CONV + RELU =================
// //   reg signed [19:0] o6_d1,o6_d2,o6_d3,o6_d4;
// //reg signed [19:0] o7_d1,o7_d2;

// //always @(posedge clk) begin
// //    if(rst) begin
// //        o6_d1 <= 0;
// //        o6_d2 <= 0;
// //        o6_d3 <= 0;
// //        o6_d4 <= 0;

// //        o7_d1 <= 0;
// //        o7_d2 <= 0;
// //    end
// //    else if(en) begin
// //        o6_d1 <= o6;
// //        o6_d2 <= o6_d1;
// //        o6_d3 <= o6_d2;
// //        o6_d4 <= o6_d3;

// //        o7_d1 <= o7;
// //        o7_d2 <= o7_d1;
// //    end
// //end

// reg signed [19:0] o6_d1,o6_d2,o6_d3,o6_d4;
// reg signed [19:0] o7_d1,o7_d2;

// always @(posedge clk) begin
//     if(rst) begin
//         o6_d1 <= 0;
//         o6_d2 <= 0;
//         o6_d3 <= 0;
//         o6_d4 <= 0;

//         o7_d1 <= 0;
//         o7_d2 <= 0;
//     end
//     else if(en) begin
//         o6_d1 <= o6;
//         o6_d2 <= o6_d1;
//         o6_d3 <= o6_d2;
//         o6_d4 <= o6_d3;

//         o7_d1 <= o7;
//         o7_d2 <= o7_d1;
//     end
// end

// wire signed [19:0] conv_sum;
// assign conv_sum = o6_d3 + o7_d2 + o8;
// //assign conv_sum = o6 + o7+ o8;        

// wire signed [19:0] relu_out;
// ReLU relu_inst (
//     .in(conv_sum),
//     .out(relu_out)
// );

// reg signed [19:0] o6_prev,o7_prev,o8_prev;

// always @(posedge clk) begin
//     if (o6!=o6_prev || o7!=o7_prev || o8!=o8_prev)
//         $display("T=%0t  o6=%0d  o7=%0d  o8=%0d",
//                  $time,o6,o7,o8);

//     o6_prev <= o6;
//     o7_prev <= o7;
//     o8_prev <= o8;
// end
//     // ================= VALID PIPELINE =================
// //    reg [7:0] valid_pipe;
    
// //    always @(posedge clk) begin
// //        if (rst)
// //            valid_pipe <= 8'b0;
// //        else if (en)
// //            valid_pipe <= {valid_pipe[6:0], 1'b1};
// //    end

//     //wire conv_valid = valid_pipe[7] & valid_window;
// ///////////////////////////////////////////////////////////////////////////////////// 
// //    reg [9:0] pixel_count;

// //    always @(posedge clk) begin
// //        if(rst)
// //            pixel_count <= 0;
// //        else if(en && pixel_count < IMG_W*IMG_W)
// //            pixel_count <= pixel_count + 1;
// //    end
    
// //    wire conv_valid = (pixel_count >= 62) && (pixel_count < IMG_W*IMG_W);
// //      wire conv_valid = (pixel_count >= 62) && (pixel_count < TOTAL_WINDOWS);

    
// //    integer conv_cnt;

// //    always @(posedge clk) begin
// //        if(rst)
// //            conv_cnt <= 0;
// //        else if(conv_valid)
// //            conv_cnt <= conv_cnt + 1;
// //    end

//     // ================= POSITION COUNTERS =================


// reg [5:0] row;
// reg [5:0] col;

// always @(posedge clk) begin
//     if(rst) begin
//         row <= 0;
//         col <= 0;
//     end
//     else if(en) begin
//         if(col == IMG_W-1) begin
//             col <= 0;
//             row <= row + 1;
//         end
//         else begin
//             col <= col + 1;
//         end
//     end
// end

// // Valid 3x3 window exists
// wire window_valid =
//         (row >= 2) &&
//         (col >= 2);

// // Systolic latency compensation
// reg [4:0] valid_pipe;

// always @(posedge clk) begin
//     if(rst)
//         valid_pipe <= 5'b0;
//     else if(en)
//         valid_pipe <= {valid_pipe[3:0], window_valid};
// end

// wire conv_valid = valid_pipe[4];

// //integer conv_cnt;

// //always @(posedge clk) begin
// //    if(rst)
// //        conv_cnt <= 0;
// //    else if(conv_valid)
// //        conv_cnt <= conv_cnt + 1;
// //end
    
    
//     //================== LINEBUFFER ===================
//     wire [19:0] row0_out, row1_out;
    
//     linebuffer_2x2 #(
//         .IMG_W(26)  
//     ) lb_2 ( 
//         .clk(clk),
//         .rst(rst),
//         .en(en),
//         .pixel_in(relu_out),
//         .row0(row0_out),
//         .row1(row1_out)
//         );
    
//     // ================= RESULT VALID =================
//     reg result_valid;
//     always @(posedge clk) begin
//         if (rst)
//             result_valid <= 0;
//         else
//             result_valid <= conv_valid;
//     end

//     // ================= MAXPOOL =================
//     wire signed [19:0] pool_out;
//     wire pool_valid;
    
//     maxpool #(
//         .IMG_W(OUT_W),
//         .DATA_W(20)
//     ) pool_inst (
//         .clk(clk),
//         .rst(rst),
//         .en(conv_valid),
//         .row0_in(row0_out),
//         .row1_in(row1_out),
//         .data_out(pool_out),
//         .valid_out(pool_valid)
//     );

//     // ================= POOL WRITE =================
//     reg [4:0] pr, pc;

//     always @(posedge clk) begin
//         if (rst) begin
//             pr <= 0;
//             pc <= 0;
//             done <= 0;
//         end 
//         else if (pool_valid) begin

//             pool_bram[pr * POOL_W + pc] <= pool_out;

//             if (pc == POOL_W - 1) begin
//                 pc <= 0;
//                 pr <= pr + 1;
//             end else begin
//                 pc <= pc + 1;
//             end

//             if (pr == POOL_W-1 && pc == POOL_W-1)
//                 done <= 1;
//         end
//     end

//     // ================= READ =================
//     always @(posedge clk) begin
//         if (rd_en)
//             rd_data <= pool_bram[rd_addr];
//     end

// endmodule