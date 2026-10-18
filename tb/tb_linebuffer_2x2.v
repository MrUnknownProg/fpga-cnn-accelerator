`timescale 1ns/1ps

// Self-checking testbench for linebuffer_2x2.
// Uses the module's real default size, IMG_W=26, IMG_H=26 (a 26x26
// feature map - e.g. the output of a 3x3 valid conv over a 28x28 image).
// pixel_in is driven as a simple incrementing counter (1,2,3,...) so
// row0/row1 correctness is easy to verify: row1 at any valid cycle
// should equal whatever row0 was IMG_W cycles earlier (or 0, during
// fill/drain where no such sample exists yet).
module linebuffer_2x2_tb;

    localparam IMG_W = 26;
    localparam IMG_H = 26;
    localparam TOTAL = IMG_W * IMG_H;
    localparam EXPECT_VALID = TOTAL + IMG_W;

    reg         clk = 0;
    reg         rst = 1;
    reg         start = 0;
    reg [19:0]  pixel_in = 20'd0;

    wire [19:0] row0, row1;
    wire        valid, done;

    linebuffer_2x2 #(.IMG_W(IMG_W), .IMG_H(IMG_H)) dut (
        .clk(clk), .rst(rst), .start(start), .pixel_in(pixel_in),
        .row0(row0), .row1(row1), .valid(valid), .done(done)
    );

    always #5 clk = ~clk;

    // reference model of row0 values, used to check row1 against the
    // value row0 held IMG_W valid-cycles earlier
    reg [19:0] row0_hist [0:1023];
    integer    wr_idx;
    integer    valid_count;
    integer    errors;
    reg [19:0] pix_counter;
    reg        feeding;

    initial begin
        wr_idx      = 0;
        valid_count = 0;
        errors      = 0;
        pix_counter = 20'd0;
        feeding     = 0;

        rst = 1; start = 0; pixel_in = 20'd0;
        repeat (2) @(posedge clk); #1;
        rst = 0;
        @(posedge clk); #1;

        start = 1;
        pix_counter = 20'd1;
        pixel_in = pix_counter;      // first real pixel ready on the sampling edge
        feeding = 1;
        @(posedge clk); #1;
        start = 0;

        $display("[%0t] start sampled: running=%0b row0=%0d row1=%0d valid=%0b (expect valid=0, 1 edge before first data)",
                  $time, dut.running, row0, row1, valid);
        if (valid !== 1'b0) begin
            errors = errors + 1;
            $display("[%0t] FAIL: expected valid=0 on the edge that samples start", $time);
        end

        while (!done) begin
            // advance the pixel counter each cycle while the DUT is still
            // accepting real input (mirror dut.running one step ahead so
            // pixel_in is ready before the sampling edge)
            if (feeding) begin
                pix_counter = pix_counter + 20'd1;
                pixel_in = pix_counter;
            end

            @(posedge clk); #1;

            if (dut.running == 1'b0 && feeding == 1'b1) begin
                feeding = 0; // last real pixel already accepted; stop advancing
            end

            if (valid) begin
                valid_count = valid_count + 1;

                // check row1 against row0's value from IMG_W valid-cycles ago
                if (valid_count > IMG_W) begin
                    if (row1 !== row0_hist[valid_count - IMG_W]) begin
                        errors = errors + 1;
                        $display("[%0t] FAIL row1=%0d expected %0d (row0 from %0d cycles ago)",
                                  $time, row1, row0_hist[valid_count - IMG_W], IMG_W);
                    end
                end
                else begin
                    if (row1 !== 20'd0) begin
                        errors = errors + 1;
                        $display("[%0t] FAIL row1=%0d expected 0 (still filling)", $time, row1);
                    end
                end
                row0_hist[valid_count] = row0;

                $display("[%0t] valid  row0=%0d  row1=%0d  done=%0b", $time, row0, row1, done);
            end
        end

        // one more cycle to confirm everything has gone to 0
        @(posedge clk); #1;
        $display("[%0t] post-done  row0=%0d row1=%0d valid=%0b done=%0b", $time, row0, row1, valid, done);
        if (row0 !== 0 || row1 !== 0 || valid !== 0) begin
            errors = errors + 1;
            $display("[%0t] FAIL: expected everything 0 the cycle after done", $time);
        end

        $display("--------------------------------------------------");
        $display("valid beats seen : %0d", valid_count);
        $display("expected beats   : %0d", EXPECT_VALID);
        if (valid_count !== EXPECT_VALID) begin
            errors = errors + 1;
            $display("FAIL: valid beat count mismatch");
        end

        if (errors == 0)
            $display("RESULT: PASS (%0d errors)", errors);
        else
            $display("RESULT: FAIL (%0d errors)", errors);

        $finish;
    end

endmodule