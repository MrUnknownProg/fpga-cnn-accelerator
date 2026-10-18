module mac_vedic (
    input            clk,
    input            en,
    input            rst,

    input  signed [7:0]     pixel_in,
    output reg signed [7:0] pixel_out,

    input  signed [7:0]     weight_in,
    output reg signed [7:0] weight_out,

    input  signed [19:0]    acc_in,
    output reg signed [19:0] acc_out
);

    // -----------------------------
    // STEP 1: Extract signs
    // -----------------------------
    wire sign = pixel_in[7] ^ weight_in[7];

    // -----------------------------
    // STEP 2: Convert to magnitude
    // -----------------------------
    wire [7:0] pixel_mag  = pixel_in[7]  ? (~pixel_in + 1)  : pixel_in;
    wire [7:0] weight_mag = weight_in[7] ? (~weight_in + 1) : weight_in;

    // -----------------------------
    // STEP 3: Unsigned Vedic multiply
    // -----------------------------
    wire [15:0] prod_unsigned;

    vedic_8x8 mul (
        .a(pixel_mag),
        .b(weight_mag),
        .p(prod_unsigned)
    );

    // -----------------------------
    // STEP 4: Restore sign
    // -----------------------------
    wire signed [15:0] prod_signed =
        sign ? -$signed(prod_unsigned) : $signed(prod_unsigned);

    // -----------------------------
    // STEP 5: Sign extend to 20-bit
    // -----------------------------
    wire signed [19:0] prod_ext = {{4{prod_signed[15]}}, prod_signed};

    // -----------------------------
    // STEP 6: MAC operation
    // -----------------------------
    always @(posedge clk) begin

      if (rst) begin
          acc_out    <= 0;
          pixel_out  <= 0;
          weight_out <= 0;
      end

      else if (en) begin
          acc_out <= $signed(acc_in) + prod_ext;

          // Systolic forwarding
          pixel_out  <= pixel_in;
          weight_out <= weight_in;
      end
      
      else begin
        acc_out    <= acc_out;
        pixel_out  <= pixel_out;
        weight_out <= weight_out;
    end
    end

endmodule